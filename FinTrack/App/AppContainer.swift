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
    let balanceService: BalanceService
    let budgetService: BudgetService
    let analyticsService: AnalyticsService
    let recurringService: RecurringService

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
        enableSyncedMode()
        bumpSessionEpoch()
    }

    func register(email: String, password: String, name: String?) async throws {
        try await authManager.register(email: email, password: password, name: name)
        needsReauthentication = false
        authBannerMessage = nil
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

    private func bumpSessionEpoch() {
        sessionEpoch += 1
        notifyChange()
    }

    func performSync() async {
        guard let syncEngine else { return }
        await syncEngine.syncNow()
        syncStatus = syncEngine.status
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

    // MARK: - Seed

    func seedDefaultCategoriesIfNeeded() {
        do {
            let existing = try categories.fetchAll()
            if existing.isEmpty {
                for category in SeedDataService.defaultCategories() {
                    try categories.save(category)
                }
                UserDefaults.standard.set(true, forKey: AppStorageKeys.hasSeededSubcategories)
                notifyChange()
                return
            }
            seedSubcategoriesIfNeeded()
        } catch {
            // Ignore seed failures on first launch.
        }
    }

    private func seedSubcategoriesIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppStorageKeys.hasSeededSubcategories) else { return }

        do {
            let roots = try categories.fetchRoots()
            for root in roots {
                let existingNames = Set(root.children.map(\.name))
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
