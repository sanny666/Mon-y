import Foundation
import Observation
import SwiftData
import UIKit
import WidgetKit

enum DataMode: String {
    case local
    case synced
}

@Observable
@MainActor
final class AppContainer {
    private(set) var accounts: AccountRepository
    private(set) var categories: CategoryRepository
    private(set) var transactions: TransactionRepository
    private(set) var budgets: BudgetRepository
    private(set) var goals: GoalRepository
    private(set) var recurring: RecurringTransactionRepository
    private(set) var itemDictionary: ItemDictionaryRepository
    let balanceService: BalanceService
    let budgetService: BudgetService
    let analyticsService: AnalyticsService
    let recurringService: RecurringService
    let voiceInput = VoiceInputService()

    let authManager: AuthManager
    private let apiClient: APIClient
    private(set) var syncEngine: SyncEngine?
    private(set) var dataMode: DataMode = .local
    private(set) var syncStatus: SyncStatus = .idle
    /// Set when refresh fails — UI should offer login again.
    var needsReauthentication = false
    var authBannerMessage: String?
    /// Bumps on login / register / logout / session expiry so RootView re-evaluates the auth gate.
    private(set) var sessionEpoch: Int = 0
    var isLoggedIn: Bool { authManager.isLoggedIn }

    private let context: ModelContext
    var refreshToken: Int = 0

    private var periodicSyncTask: Task<Void, Never>?
    private var debounceSyncTask: Task<Void, Never>?
    private var periodicMaintenanceTask: Task<Void, Never>?
    /// After the first cloud sync attempt we may seed defaults if the account is empty.
    private var didAttemptInitialCloudRestore = false

    init(context: ModelContext) {
        self.context = context
        self.balanceService = BalanceService()
        self.budgetService = BudgetService()
        self.analyticsService = AnalyticsService()
        self.recurringService = RecurringService()
        self.authManager = AuthManager()

        // Temporary local wiring; may switch to synced below.
        self.accounts = SwiftDataAccountRepository(context: context)
        self.categories = SwiftDataCategoryRepository(context: context)
        self.transactions = SwiftDataTransactionRepository(context: context)
        self.budgets = SwiftDataBudgetRepository(context: context)
        self.goals = SwiftDataGoalRepository(context: context)
        self.recurring = SwiftDataRecurringTransactionRepository(context: context)
        self.itemDictionary = SwiftDataItemDictionaryRepository(context: context)

        let auth = self.authManager
        self.apiClient = APIClient(
            accessTokenProvider: { auth.accessToken },
            refreshHandler: { try await auth.refreshToken() },
            onAuthFailure: { await auth.handleAuthFailure() }
        )

        authManager.onSessionExpired = { [weak self] in
            Task { @MainActor in
                self?.disableSyncedMode()
                self?.needsReauthentication = true
                self?.authBannerMessage = "Сессия истекла. Войдите снова."
                self?.syncStatus = .error("Сессия истекла")
                self?.bumpSessionEpoch()
                self?.notifyChange()
            }
        }

        if authManager.isLoggedIn {
            enableSyncedMode()
        }
        startPeriodicMaintenance()
    }

    func notifyChange() {
        refreshToken += 1
        publishWidgetSnapshot()
    }

    /// Writes a lightweight JSON snapshot for the home-screen widget (App Group).
    func publishWidgetSnapshot(defaultCurrency: String? = nil) {
        let currencyFallback = defaultCurrency
            ?? UserDefaults.standard.string(forKey: AppStorageKeys.defaultCurrency)
            ?? AppCurrency.kzt.rawValue

        do {
            let accounts = try accounts.fetchAll()
            let total = balanceService.totalBalance(accounts: accounts)
            let currencyCode = accounts.first?.currency ?? currencyFallback
            let balanceText = CurrencyFormatter.string(amount: total, currencyCode: currencyCode)

            let recentExpenses = try transactions.fetchRecent(limit: 30)
                .filter { $0.type == .expense }
                .prefix(3)
                .map { tx -> WidgetExpenseItem in
                    let title: String
                    if !tx.note.isEmpty {
                        title = tx.note
                    } else {
                        title = tx.category?.displayName ?? "Расход"
                    }
                    let txCurrency = tx.account?.currency ?? currencyCode
                    return WidgetExpenseItem(
                        id: tx.id.uuidString,
                        title: title,
                        amountText: CurrencyFormatter.string(amount: tx.amount, currencyCode: txCurrency),
                        dateText: tx.date.formatted(date: .abbreviated, time: .omitted)
                    )
                }

            let snapshot = WidgetSnapshot(
                balanceText: balanceText,
                currencyCode: currencyCode,
                recentExpenses: Array(recentExpenses),
                updatedAt: .now
            )
            WidgetSnapshotStore.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Keep app responsive; widget shows previous snapshot.
        }
    }

    /// Materializes due recurring templates. Safe in both `.local` and `.synced`
    /// (does not depend on SyncEngine). Reminder scheduling is separate from tx creation.
    func processDueRecurring() {
        do {
            let items = try recurring.fetchAll()
            let created = try recurringService.processDue(
                items: items,
                createTransaction: { item, date in
                    let tx = Transaction(
                        amount: item.amount,
                        type: item.type,
                        date: date,
                        note: item.note,
                        account: item.account,
                        category: item.category
                    )
                    try self.transactions.save(tx)
                },
                saveItem: { item in
                    try self.recurring.save(item)
                    self.rescheduleRecurringReminder(for: item)
                }
            )
            if created > 0 {
                recalculateBudgets()
                notifyChange()
            }
        } catch {
            // Keep UI responsive; errors surface via missing data.
        }
    }

    func rescheduleRecurringReminder(for item: RecurringTransaction) {
        let title = item.note.isEmpty ? item.type.title : item.note
        let currency = item.account?.currency ?? AppCurrency.kzt.rawValue
        let amountText = CurrencyFormatter.string(amount: item.amount, currencyCode: currency)
        NotificationService.shared.scheduleRecurringReminder(
            id: item.id,
            title: title,
            amountText: amountText,
            nextDate: item.nextDate
        )
    }

    func recalculateBudgets() {
        do {
            let allBudgets = try budgets.fetchAll()
            let allTransactions = try transactions.fetchAll()
            let dirtyBudgets = budgetService.recalculateAll(budgets: allBudgets, transactions: allTransactions)
            for budget in dirtyBudgets {
                budget.updatedAt = .now
                budget.isSynced = false
            }
            try context.save()
            if !dirtyBudgets.isEmpty, dataMode == .synced {
                scheduleSyncDebounced()
            }
            notifyChange()
        } catch {
            // Keep UI responsive; errors surface via empty data.
        }
    }

    // MARK: - Mode switching

    func enableSyncedMode() {
        let schedule: () -> Void = { [weak self] in
            self?.scheduleSyncDebounced()
        }
        accounts = NetworkAccountRepository(context: context, api: apiClient, scheduleSync: schedule)
        categories = NetworkCategoryRepository(context: context, api: apiClient, scheduleSync: schedule)
        transactions = NetworkTransactionRepository(context: context, api: apiClient, scheduleSync: schedule)
        budgets = NetworkBudgetRepository(context: context, api: apiClient, scheduleSync: schedule)
        goals = NetworkGoalRepository(context: context, api: apiClient, scheduleSync: schedule)
        recurring = NetworkRecurringTransactionRepository(context: context, api: apiClient, scheduleSync: schedule)

        let engine = SyncEngine(
            context: context,
            api: apiClient,
            recalculateBudgets: { [weak self] in self?.recalculateBudgets() },
            onDataChanged: { [weak self] in self?.notifyChange() }
        )
        syncEngine = engine
        dataMode = .synced
        startPeriodicSync()
        startPeriodicMaintenance()
        Task { await performSync() }
    }

    func disableSyncedMode() {
        periodicSyncTask?.cancel()
        periodicSyncTask = nil
        debounceSyncTask?.cancel()
        debounceSyncTask = nil
        syncEngine = nil
        syncStatus = .idle

        accounts = SwiftDataAccountRepository(context: context)
        categories = SwiftDataCategoryRepository(context: context)
        transactions = SwiftDataTransactionRepository(context: context)
        budgets = SwiftDataBudgetRepository(context: context)
        goals = SwiftDataGoalRepository(context: context)
        recurring = SwiftDataRecurringTransactionRepository(context: context)
        dataMode = .local
        startPeriodicMaintenance()
        notifyChange()
    }

    func login(email: String, password: String) async throws {
        try await authManager.login(email: email, password: password)
        needsReauthentication = false
        authBannerMessage = nil
        // Force full pull so reinstall / new device restores cloud history.
        UserDefaults.standard.removeObject(forKey: "sync.lastServerTime")
        enableSyncedMode()
        bumpSessionEpoch()
    }

    func register(email: String, password: String, name: String?) async throws {
        try await authManager.register(email: email, password: password, name: name)
        needsReauthentication = false
        authBannerMessage = nil
        UserDefaults.standard.removeObject(forKey: "sync.lastServerTime")
        enableSyncedMode()
        bumpSessionEpoch()
    }

    func logout() async {
        await authManager.logout()
        disableSyncedMode()
        needsReauthentication = false
        authBannerMessage = nil
        bumpSessionEpoch()
    }

    func updateProfileName(_ name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = UpdateProfileRequestDTO(name: trimmed.isEmpty ? nil : trimmed)
        do {
            let user: AuthUserDTO = try await apiClient.patch("/v1/auth/me", body: payload)
            authManager.applyUser(user)
        } catch let error as NetworkError {
            if case .http(let status, _, _) = error, status == 404 {
                authManager.setLocalName(trimmed.isEmpty ? nil : trimmed)
            } else {
                throw error
            }
        }
        notifyChange()
    }

    func changePassword(current: String, new: String) async throws {
        let payload = ChangePasswordRequestDTO(currentPassword: current, newPassword: new)
        do {
            try await apiClient.postEmpty("/v1/auth/change-password", body: payload)
        } catch let error as NetworkError {
            if case .http(let status, _, _) = error, status == 404 {
                throw NetworkError.http(
                    status: 404,
                    code: nil,
                    message: "Сервер пока не поддерживает смену пароля."
                )
            }
            throw error
        }
    }

    private func bumpSessionEpoch() {
        sessionEpoch += 1
        notifyChange()
    }

    func performSync() async {
        guard let syncEngine else { return }
        // Heal reinstall bug: push advanced the cursor before pull, so historical
        // cloud data was skipped. If we never restored any synced transactions,
        // force a full pull (safe for brand-new accounts too).
        if syncEngine.lastSyncDate != nil {
            let syncedTransactions = (try? context.fetch(
                FetchDescriptor<Transaction>(predicate: #Predicate { $0.isSynced == true })
            )) ?? []
            if syncedTransactions.isEmpty {
                syncEngine.resetSyncCursor()
            }
        }
        await syncEngine.syncNow()
        syncStatus = syncEngine.status
        didAttemptInitialCloudRestore = true
        // After cloud restore: seed only if still empty, then collapse name duplicates.
        seedDefaultCategoriesIfNeeded()
        dedupeCategoriesIfNeeded()
        notifyChange()
    }

    func loadAttachmentImage(urlString: String?) async -> UIImage? {
        await AttachmentImageCache.loadImage(urlString: urlString, api: apiClient)
    }

    func handleSceneBecameActive() {
        // Recurring first — always, including `.local` without login.
        processDueRecurring()
        publishWidgetSnapshot()
        guard dataMode == .synced else { return }
        Task { await performSync() }
    }

    private func scheduleSyncDebounced() {
        guard dataMode == .synced else { return }
        debounceSyncTask?.cancel()
        debounceSyncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await self?.performSync()
        }
    }

    private func startPeriodicSync() {
        periodicSyncTask?.cancel()
        periodicSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                let ns = UInt64(AppConfig.syncInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                guard !Task.isCancelled else { return }
                await self?.performSync()
            }
        }
    }

    /// Recurring due-check loop. Runs in both `.local` and `.synced` (independent of
    /// `startPeriodicSync`, which is synced-only).
    private func startPeriodicMaintenance() {
        periodicMaintenanceTask?.cancel()
        periodicMaintenanceTask = Task { [weak self] in
            while !Task.isCancelled {
                let ns = UInt64(AppConfig.syncInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.processDueRecurring()
                }
            }
        }
    }

    // MARK: - Voice parsing

    func parseVoiceTranscript(_ text: String) throws -> VoiceParseResult {
        let accounts = try accounts.fetchAll()
        let defaultID = DefaultAccountResolver.resolvedID(from: accounts)
        var result = TransactionParser.parse(
            VoiceParseInput(
                text: text,
                accounts: accounts,
                defaultAccountID: defaultID
            )
        )

        let allCategories = try categories.fetchAll().flatMap { [$0] + $0.children }
        let searchTerms = TransactionParser.voiceSearchTerms(itemName: result.itemName, transcript: text)

        for term in searchTerms {
            if let match = try itemDictionary.findMatch(for: term),
               let categoryID = match.category?.id {
                result.matchedCategoryID = categoryID
                result.matchHint = "по совпадению с «\(match.canonicalName)»"
                return result
            }
        }

        if let category = BankStatementParser.matchCategory(
            note: result.itemName,
            hint: text,
            type: result.type,
            categories: allCategories
        ) {
            result.matchedCategoryID = category.id
            let hintTerm = result.itemName.isEmpty
                ? (searchTerms.first(where: { $0.count >= 3 }) ?? category.name)
                : result.itemName
            result.matchHint = "по ключевому слову «\(hintTerm)»"
        }

        return result
    }

    // MARK: - Seed

    func seedDefaultCategoriesIfNeeded() {
        do {
            let existing = try categories.fetchAll()
            if existing.isEmpty {
                // Logged-in installs restore categories from cloud first; seeding here
                // races sync and creates permanent name duplicates on the server.
                if isLoggedIn, syncEngine != nil, !didAttemptInitialCloudRestore {
                    return
                }
                for category in SeedDataService.defaultCategories() {
                    try categories.save(category)
                }
                UserDefaults.standard.set(true, forKey: AppStorageKeys.hasSeededSubcategories)
                seedDefaultItemDictionaryIfNeeded()
                notifyChange()
                return
            }
            dedupeCategoriesIfNeeded()
            seedSubcategoriesIfNeeded()
            seedDefaultItemDictionaryIfNeeded()
        } catch {
            // Ignore seed failures on first launch.
        }
    }

    /// Collapses duplicate categories with the same type + parent + name.
    /// Prefer synced / heavily used rows; reassign relations; soft-delete losers for sync.
    func dedupeCategoriesIfNeeded() {
        do {
            var changed = false
            // Several passes: reparenting can create new same-name siblings.
            for _ in 0..<4 {
                let all = try context.fetch(
                    FetchDescriptor<Category>(predicate: #Predicate { $0.isDeleted == false })
                )
                guard !all.isEmpty else { return }

                var passChanged = false

                // 1) Roots by type + name.
                let roots = all.filter { $0.parent == nil }
                passChanged = mergeDuplicateGroups(roots, among: all) { cat in
                    "\(cat.typeRaw)|root|\(normalizedCategoryName(cat.name))"
                } || passChanged

                // Refresh after root merges so child parent pointers are current.
                let afterRoots = try context.fetch(
                    FetchDescriptor<Category>(predicate: #Predicate { $0.isDeleted == false })
                )

                // 2) Children by parent id + name (same parent).
                let children = afterRoots.filter { $0.parent != nil }
                passChanged = mergeDuplicateGroups(children, among: afterRoots) { cat in
                    let parentKey = cat.parent?.id.uuidString ?? "nil"
                    return "\(cat.typeRaw)|child|\(parentKey)|\(normalizedCategoryName(cat.name))"
                } || passChanged

                // 3) Children by parent name + child name (orphans under duplicate parents).
                let afterChildren = try context.fetch(
                    FetchDescriptor<Category>(predicate: #Predicate { $0.isDeleted == false })
                ).filter { $0.parent != nil }
                passChanged = mergeDuplicateGroups(afterChildren, among: afterChildren) { cat in
                    let parentName = normalizedCategoryName(cat.parent?.name ?? "")
                    return "\(cat.typeRaw)|byParentName|\(parentName)|\(normalizedCategoryName(cat.name))"
                } || passChanged

                if passChanged {
                    changed = true
                } else {
                    break
                }
            }

            if changed {
                try context.save()
                notifyChange()
                if dataMode == .synced {
                    scheduleSyncDebounced()
                }
            }
        } catch {
            // Best-effort heal.
        }
    }

    private func normalizedCategoryName(_ name: String) -> String {
        name
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mergeDuplicateGroups(
        _ items: [Category],
        among allKnown: [Category],
        key: (Category) -> String
    ) -> Bool {
        let grouped = Dictionary(grouping: items, by: key)
        var changed = false
        for (_, group) in grouped where group.count > 1 {
            let ranked = group.sorted(by: Self.preferredCategory)
            guard let keeper = ranked.first else { continue }
            for loser in ranked.dropFirst() where !loser.isDeleted {
                absorb(loser, into: keeper, among: allKnown)
                changed = true
            }
        }
        return changed
    }

    /// Higher is better — synced + more usage wins.
    private static func preferredCategory(_ lhs: Category, _ rhs: Category) -> Bool {
        let lScore = categoryKeepScore(lhs)
        let rScore = categoryKeepScore(rhs)
        if lScore != rScore { return lScore > rScore }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func categoryKeepScore(_ category: Category) -> Int {
        var score = 0
        if category.isSynced { score += 1_000 }
        if category.serverID != nil { score += 100 }
        score += category.transactions.filter { !$0.isDeleted }.count * 10
        score += category.budgets.filter { !$0.isDeleted }.count * 5
        score += category.recurringTemplates.filter { !$0.isDeleted }.count * 5
        score += category.dictionaryEntries.filter { !$0.isDeleted }.count
        score += category.children.filter { !$0.isDeleted }.count
        return score
    }

    private func absorb(_ loser: Category, into keeper: Category, among allKnown: [Category]) {
        // Don't trust relationship arrays alone — reparent via parent pointer scan.
        for child in allKnown where !child.isDeleted && child.parent?.id == loser.id {
            child.parent = keeper
            child.updatedAt = .now
            child.isSynced = false
        }
        for child in loser.children where !child.isDeleted {
            child.parent = keeper
            child.updatedAt = .now
            child.isSynced = false
        }

        for tx in loser.transactions where !tx.isDeleted {
            tx.category = keeper
            tx.updatedAt = .now
            tx.isSynced = false
        }
        for budget in loser.budgets where !budget.isDeleted {
            budget.category = keeper
            budget.updatedAt = .now
            budget.isSynced = false
        }
        for item in loser.recurringTemplates where !item.isDeleted {
            item.category = keeper
            item.updatedAt = .now
            item.isSynced = false
        }
        for entry in loser.dictionaryEntries where !entry.isDeleted {
            entry.category = keeper
            entry.updatedAt = .now
            entry.isSynced = false
        }

        // If absorbing a child into another under a different parent, park under keeper's parent.
        if keeper.parent != nil, loser.parent?.id != keeper.parent?.id {
            loser.parent = keeper.parent
        }

        loser.isDeleted = true
        loser.updatedAt = .now
        loser.isSynced = false
    }

    func seedDefaultItemDictionaryIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppStorageKeys.hasSeededItemDictionary) else { return }

        do {
            let allCategories = try categories.fetchAll().flatMap { [$0] + $0.children }
            for seed in SeedDataService.defaultDictionary {
                guard let category = SeedDataService.resolveCategory(named: seed.categoryName, in: allCategories) else {
                    continue
                }
                try itemDictionary.insertSeed(name: seed.itemName, aliases: seed.aliases, category: category)
            }

            defaults.set(true, forKey: AppStorageKeys.hasSeededItemDictionary)
        } catch {
            // Retry next launch if seed fails.
        }
    }

    private func seedSubcategoriesIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppStorageKeys.hasSeededSubcategories) else { return }

        do {
            let roots = try categories.fetchRoots()
            // Avoid attaching the same seed tree to every duplicate parent name.
            var seenRootNames = Set<String>()
            for root in roots {
                let key = "\(root.typeRaw)|\(root.name.lowercased())"
                guard seenRootNames.insert(key).inserted else { continue }
                let existingNames = Set(root.children.filter { !$0.isDeleted }.map(\.name))
                let seeds = SeedDataService.subcategorySeeds(forParentName: root.name)
                for seed in seeds where !existingNames.contains(seed.name) {
                    let child = Category(
                        name: seed.name,
                        icon: seed.icon,
                        colorHex: root.colorHex,
                        type: root.type,
                        parent: root
                    )
                    try categories.save(child)
                }
            }
            defaults.set(true, forKey: AppStorageKeys.hasSeededSubcategories)
            notifyChange()
        } catch {
            // Retry next launch if upgrade fails.
        }
    }
}
