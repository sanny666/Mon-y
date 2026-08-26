import Foundation
import SwiftData
import UIKit

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success(Date)
    case error(String)
}

/// Pushes pending local changes and pulls remote updates. Offline failures are silent.
@MainActor
final class SyncEngine {
    private let context: ModelContext
    private let api: APIClient
    private let recalculateBudgets: () -> Void
    private let onDataChanged: () -> Void

    private(set) var status: SyncStatus = .idle
    private var isRunning = false

    private static let lastSyncKey = "sync.lastServerTime"

    init(
        context: ModelContext,
        api: APIClient,
        recalculateBudgets: @escaping () -> Void,
        onDataChanged: @escaping () -> Void
    ) {
        self.context = context
        self.api = api
        self.recalculateBudgets = recalculateBudgets
        self.onDataChanged = onDataChanged
    }

    var lastSyncDate: Date? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Self.lastSyncKey) else { return nil }
            return ISO8601Codec.date(from: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(ISO8601Codec.string(from: newValue), forKey: Self.lastSyncKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.lastSyncKey)
            }
        }
    }

    func syncNow() async {
        guard !isRunning else { return }
        isRunning = true
        status = .syncing
        defer { isRunning = false }

        do {
            try await uploadPendingAttachments()
            try await pushPendingChanges()
            try await pullRemoteChanges(since: lastSyncDate)
            status = .success(Date())
            onDataChanged()
        } catch let error as NetworkError {
            if case .unauthorized = error {
                status = .error("Сессия истекла")
            } else if case .noConnection = error {
                status = .error("Нет сети")
            } else if case .timeout = error {
                status = .error("Таймаут сети")
            } else if error.isConnectivityFailure {
                status = .error("Нет сети")
            } else {
                status = .error("Ошибка сервера")
            }
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func pushPendingChanges() async throws {
        let accounts = try pendingAccounts().map(DTOMapper.dto(from:))
        let categories = try pendingCategories().map(DTOMapper.dto(from:))
        let transactions = try pendingTransactions().map(DTOMapper.dto(from:))
        let budgets = try pendingBudgets().map(DTOMapper.dto(from:))
        let goals = try pendingGoals().map(DTOMapper.dto(from:))
        let recurring = try pendingRecurring().map(DTOMapper.dto(from:))

        let isEmpty = accounts.isEmpty && categories.isEmpty && transactions.isEmpty
            && budgets.isEmpty && goals.isEmpty && recurring.isEmpty
        guard !isEmpty else { return }

        let request = SyncPushRequest(
            accounts: .init(changes: accounts),
            categories: .init(changes: categories),
            transactions: .init(changes: transactions),
            budgets: .init(changes: budgets),
            goals: .init(changes: goals),
            recurringTransactions: .init(changes: recurring)
        )

        let response: SyncPushResponse = try await api.post("/v1/sync/push", body: request)

        markAccountsSynced(Set(response.accepted.accounts))
        markCategoriesSynced(Set(response.accepted.categories))
        markTransactionsSynced(Set(response.accepted.transactions))
        markBudgetsSynced(Set(response.accepted.budgets))
        markGoalsSynced(Set(response.accepted.goals))
        markRecurringSynced(Set(response.accepted.recurringTransactions))

        try context.save()

        if !response.conflicts.isEmpty {
            // Server won for these IDs — force-apply payload (do not keep unsynced local).
            try applyConflicts(response.conflicts)
            recalculateBudgets()
            try context.save()
        }

        lastSyncDate = response.serverTime
    }

    private func applyConflicts(_ conflicts: [SyncConflictDTO]) throws {
        for conflict in conflicts {
            if let dto = conflict.serverAccount {
                try upsertAccount(dto, force: true)
            } else if let dto = conflict.serverCategory {
                try upsertCategory(dto, force: true)
            } else if let dto = conflict.serverTransaction {
                try upsertTransaction(dto, force: true)
            } else if let dto = conflict.serverBudget {
                try upsertBudget(dto, force: true)
            } else if let dto = conflict.serverGoal {
                try upsertGoal(dto, force: true)
            } else if let dto = conflict.serverRecurring {
                try upsertRecurring(dto, force: true)
            }
        }
    }

    func pullRemoteChanges(since: Date?) async throws {
        let sinceValue = since.map(ISO8601Codec.string(from:)) ?? "1970-01-01T00:00:00.000Z"
        let encoded = sinceValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sinceValue
        let path = "/v1/sync?since=\(encoded)"

        let response: SyncPullResponse = try await api.get(path)
        try applyPull(response)
        recalculateBudgets()
        lastSyncDate = response.serverTime
        try context.save()
    }

    // MARK: - Attachments

    private func uploadPendingAttachments() async throws {
        let txs = try pendingTransactions().filter { tx in
            guard let raw = tx.attachmentURL, let url = URL(string: raw) else { return false }
            return url.isFileURL
        }
        for tx in txs {
            guard let raw = tx.attachmentURL, let fileURL = URL(string: raw),
                  let data = try? Data(contentsOf: fileURL) else { continue }
            do {
                let uploaded: AttachmentUploadResponse = try await api.uploadMultipart(
                    path: "/v1/transactions/\(tx.id.uuidString)/attachment",
                    fileData: data,
                    fileName: "\(tx.id.uuidString).jpg",
                    mimeType: "image/jpeg"
                )
                tx.attachmentURL = uploaded.attachmentURL
                tx.updatedAt = uploaded.updatedAt
                tx.isSynced = false
            } catch let error as NetworkError where error.isConnectivityFailure {
                throw error
            } catch {
                // Keep local file URL; retry later.
            }
        }
        try context.save()
    }

    // MARK: - Apply pull

    private func applyPull(_ response: SyncPullResponse) throws {
        for dto in response.categories.changes {
            try upsertCategory(dto)
        }
        for dto in response.accounts.changes {
            try upsertAccount(dto)
        }
        for dto in response.transactions.changes {
            try upsertTransaction(dto)
        }
        for dto in response.budgets.changes {
            try upsertBudget(dto)
        }
        for dto in response.goals.changes {
            try upsertGoal(dto)
        }
        for dto in response.recurringTransactions.changes {
            try upsertRecurring(dto)
        }
    }

    private func upsertAccount(_ dto: AccountDTO, force: Bool = false) throws {
        let existing = try fetchAccount(id: dto.id)
        if !force, let existing, existing.updatedAt > dto.updatedAt, !existing.isSynced { return }
        let account = existing ?? Account(
            id: dto.id,
            name: dto.name,
            type: AccountType(rawValue: dto.type) ?? .cash,
            currency: dto.currency,
            initialBalance: dto.initialBalance,
            icon: dto.icon,
            colorHex: dto.colorHex,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            isSynced: true,
            isDeleted: dto.isDeleted
        )
        if existing == nil { context.insert(account) }
        DTOMapper.apply(dto, to: account)
    }

    private func upsertCategory(_ dto: CategoryDTO, force: Bool = false) throws {
        let existing = try fetchCategory(id: dto.id)
        if !force, let existing, existing.updatedAt > dto.updatedAt, !existing.isSynced { return }
        let parent = try dto.parentId.flatMap { try fetchCategory(id: $0) }
        let category = existing ?? Category(
            id: dto.id,
            name: dto.name,
            icon: dto.icon,
            colorHex: dto.colorHex,
            type: CategoryType(rawValue: dto.type) ?? .expense,
            parent: parent,
            updatedAt: dto.updatedAt,
            isSynced: true,
            isDeleted: dto.isDeleted
        )
        if existing == nil { context.insert(category) }
        DTOMapper.apply(dto, to: category, parent: parent)
    }

    private func upsertTransaction(_ dto: TransactionDTO, force: Bool = false) throws {
        let existing = try fetchTransaction(id: dto.id)
        if !force, let existing, existing.updatedAt > dto.updatedAt, !existing.isSynced { return }
        let account = try dto.accountId.flatMap { try fetchAccount(id: $0) }
        let toAccount = try dto.toAccountId.flatMap { try fetchAccount(id: $0) }
        let category = try dto.categoryId.flatMap { try fetchCategory(id: $0) }
        let tx = existing ?? Transaction(
            id: dto.id,
            amount: dto.amount,
            type: TransactionType(rawValue: dto.type) ?? .expense,
            date: dto.date,
            note: dto.note,
            account: account,
            toAccount: toAccount,
            category: category,
            attachmentURL: dto.attachmentURL,
            updatedAt: dto.updatedAt,
            isSynced: true,
            isDeleted: dto.isDeleted
        )
        if existing == nil { context.insert(tx) }
        DTOMapper.apply(dto, to: tx, account: account, toAccount: toAccount, category: category)
    }

    private func upsertBudget(_ dto: BudgetDTO, force: Bool = false) throws {
        let existing = try fetchBudget(id: dto.id)
        if !force, let existing, existing.updatedAt > dto.updatedAt, !existing.isSynced { return }
        let category = try dto.categoryId.flatMap { try fetchCategory(id: $0) }
        let budget = existing ?? Budget(
            id: dto.id,
            category: category,
            limitAmount: dto.limitAmount,
            period: BudgetPeriod(rawValue: dto.period) ?? .monthly,
            currentSpent: dto.currentSpent,
            updatedAt: dto.updatedAt,
            isSynced: true,
            isDeleted: dto.isDeleted
        )
        if existing == nil { context.insert(budget) }
        DTOMapper.apply(dto, to: budget, category: category)
    }

    private func upsertGoal(_ dto: GoalDTO, force: Bool = false) throws {
        let existing = try fetchGoal(id: dto.id)
        if !force, let existing, existing.updatedAt > dto.updatedAt, !existing.isSynced { return }
        let goal = existing ?? Goal(
            id: dto.id,
            name: dto.name,
            targetAmount: dto.targetAmount,
            currentAmount: dto.currentAmount,
            deadline: dto.deadline,
            icon: dto.icon,
            colorHex: dto.colorHex,
            updatedAt: dto.updatedAt,
            isSynced: true,
            isDeleted: dto.isDeleted
        )
        if existing == nil { context.insert(goal) }
        DTOMapper.apply(dto, to: goal)
    }

    private func upsertRecurring(_ dto: RecurringTransactionDTO, force: Bool = false) throws {
        let existing = try fetchRecurring(id: dto.id)
        if !force, let existing, existing.updatedAt > dto.updatedAt, !existing.isSynced { return }
        let account = try dto.accountId.flatMap { try fetchAccount(id: $0) }
        let category = try dto.categoryId.flatMap { try fetchCategory(id: $0) }
        let item = existing ?? RecurringTransaction(
            id: dto.id,
            amount: dto.amount,
            type: TransactionType(rawValue: dto.type) ?? .expense,
            note: dto.note,
            frequency: RecurringFrequency(rawValue: dto.frequency) ?? .monthly,
            nextDate: dto.nextDate,
            account: account,
            category: category,
            updatedAt: dto.updatedAt,
            isSynced: true,
            isDeleted: dto.isDeleted
        )
        if existing == nil { context.insert(item) }
        DTOMapper.apply(dto, to: item, account: account, category: category)
    }

    // MARK: - Pending queries (include tombstones)

    private func pendingAccounts() throws -> [Account] {
        try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.isSynced == false }))
    }

    private func pendingCategories() throws -> [Category] {
        try context.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.isSynced == false }))
    }

    private func pendingTransactions() throws -> [Transaction] {
        try context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.isSynced == false }))
    }

    private func pendingBudgets() throws -> [Budget] {
        try context.fetch(FetchDescriptor<Budget>(predicate: #Predicate { $0.isSynced == false }))
    }

    private func pendingGoals() throws -> [Goal] {
        try context.fetch(FetchDescriptor<Goal>(predicate: #Predicate { $0.isSynced == false }))
    }

    private func pendingRecurring() throws -> [RecurringTransaction] {
        try context.fetch(FetchDescriptor<RecurringTransaction>(predicate: #Predicate { $0.isSynced == false }))
    }

    private func fetchAccount(id: UUID) throws -> Account? {
        try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchCategory(id: UUID) throws -> Category? {
        try context.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchTransaction(id: UUID) throws -> Transaction? {
        try context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchBudget(id: UUID) throws -> Budget? {
        try context.fetch(FetchDescriptor<Budget>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchGoal(id: UUID) throws -> Goal? {
        try context.fetch(FetchDescriptor<Goal>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchRecurring(id: UUID) throws -> RecurringTransaction? {
        try context.fetch(FetchDescriptor<RecurringTransaction>(predicate: #Predicate { $0.id == id })).first
    }

    private func markAccountsSynced(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let items = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        for item in items where ids.contains(item.id) { item.isSynced = true }
    }

    private func markCategoriesSynced(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let items = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        for item in items where ids.contains(item.id) { item.isSynced = true }
    }

    private func markTransactionsSynced(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let items = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        for item in items where ids.contains(item.id) { item.isSynced = true }
    }

    private func markBudgetsSynced(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let items = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        for item in items where ids.contains(item.id) { item.isSynced = true }
    }

    private func markGoalsSynced(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let items = (try? context.fetch(FetchDescriptor<Goal>())) ?? []
        for item in items where ids.contains(item.id) { item.isSynced = true }
    }

    private func markRecurringSynced(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let items = (try? context.fetch(FetchDescriptor<RecurringTransaction>())) ?? []
        for item in items where ids.contains(item.id) { item.isSynced = true }
    }
}

// MARK: - Attachment disk cache

enum AttachmentImageCache {
    private static var directory: URL {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = root.appendingPathComponent("attachment-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(for remoteURL: String) -> URL {
        let name = remoteURL.data(using: .utf8).map { $0.base64EncodedString() } ?? UUID().uuidString
        let safe = String(name.prefix(80))
        return directory.appendingPathComponent(safe)
    }

    static func cachedImage(for remoteURL: String) -> UIImage? {
        let url = fileURL(for: remoteURL)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func store(_ data: Data, for remoteURL: String) {
        try? data.write(to: fileURL(for: remoteURL), options: .atomic)
    }

    static func loadImage(urlString: String?, api: APIClient) async -> UIImage? {
        guard let urlString else { return nil }
        if let local = AttachmentStore.loadImage(from: urlString) {
            return local
        }
        if let cached = cachedImage(for: urlString) {
            return cached
        }
        guard let url = URL(string: urlString), !url.isFileURL else { return nil }
        do {
            let data = try await api.downloadData(url: url)
            store(data, for: urlString)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
