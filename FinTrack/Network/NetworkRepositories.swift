import Foundation
import SwiftData

/// Offline-first repositories: write SwiftData immediately (`isSynced = false`),
/// then schedule SyncEngine. `isSynced = true` is set only after confirmed server accept.

final class NetworkAccountRepository: AccountRepository {
    private let local: SwiftDataAccountRepository
    private let scheduleSync: () -> Void

    init(context: ModelContext, api: APIClient, scheduleSync: @escaping () -> Void) {
        self.local = SwiftDataAccountRepository(context: context)
        self.scheduleSync = scheduleSync
        _ = api
    }

    func fetchAll() throws -> [Account] { try local.fetchAll() }
    func fetch(id: UUID) throws -> Account? { try local.fetch(id: id) }

    func save(_ account: Account) throws {
        try local.save(account)
        scheduleSync()
    }

    func delete(_ account: Account) throws {
        try local.delete(account)
        scheduleSync()
    }
}

final class NetworkCategoryRepository: CategoryRepository {
    private let local: SwiftDataCategoryRepository
    private let scheduleSync: () -> Void

    init(context: ModelContext, api: APIClient, scheduleSync: @escaping () -> Void) {
        self.local = SwiftDataCategoryRepository(context: context)
        self.scheduleSync = scheduleSync
        _ = api
    }

    func fetchAll() throws -> [Category] { try local.fetchAll() }
    func fetch(id: UUID) throws -> Category? { try local.fetch(id: id) }
    func fetch(type: CategoryType) throws -> [Category] { try local.fetch(type: type) }
    func fetchRoots() throws -> [Category] { try local.fetchRoots() }
    func fetchRoots(type: CategoryType) throws -> [Category] { try local.fetchRoots(type: type) }
    func fetchChildren(of parent: Category) throws -> [Category] { try local.fetchChildren(of: parent) }

    func save(_ category: Category) throws {
        try local.save(category)
        scheduleSync()
    }

    func delete(_ category: Category) throws {
        try local.delete(category)
        scheduleSync()
    }
}

final class NetworkTransactionRepository: TransactionRepository {
    private let local: SwiftDataTransactionRepository
    private let scheduleSync: () -> Void

    init(context: ModelContext, api: APIClient, scheduleSync: @escaping () -> Void) {
        self.local = SwiftDataTransactionRepository(context: context)
        self.scheduleSync = scheduleSync
        _ = api
    }

    func fetchAll() throws -> [Transaction] { try local.fetchAll() }
    func fetch(id: UUID) throws -> Transaction? { try local.fetch(id: id) }
    func fetchRecent(limit: Int) throws -> [Transaction] { try local.fetchRecent(limit: limit) }
    func fetch(accountID: UUID) throws -> [Transaction] { try local.fetch(accountID: accountID) }
    func fetch(filter: TransactionFilter) throws -> [Transaction] { try local.fetch(filter: filter) }

    func save(_ transaction: Transaction) throws {
        try local.save(transaction)
        scheduleSync()
    }

    func delete(_ transaction: Transaction) throws {
        try local.delete(transaction)
        scheduleSync()
    }
}

final class NetworkBudgetRepository: BudgetRepository {
    private let local: SwiftDataBudgetRepository
    private let scheduleSync: () -> Void

    init(context: ModelContext, api: APIClient, scheduleSync: @escaping () -> Void) {
        self.local = SwiftDataBudgetRepository(context: context)
        self.scheduleSync = scheduleSync
        _ = api
    }

    func fetchAll() throws -> [Budget] { try local.fetchAll() }
    func fetch(id: UUID) throws -> Budget? { try local.fetch(id: id) }

    func save(_ budget: Budget) throws {
        try local.save(budget)
        scheduleSync()
    }

    func delete(_ budget: Budget) throws {
        try local.delete(budget)
        scheduleSync()
    }
}

final class NetworkGoalRepository: GoalRepository {
    private let local: SwiftDataGoalRepository
    private let scheduleSync: () -> Void

    init(context: ModelContext, api: APIClient, scheduleSync: @escaping () -> Void) {
        self.local = SwiftDataGoalRepository(context: context)
        self.scheduleSync = scheduleSync
        _ = api
    }

    func fetchAll() throws -> [Goal] { try local.fetchAll() }
    func fetch(id: UUID) throws -> Goal? { try local.fetch(id: id) }

    func save(_ goal: Goal) throws {
        try local.save(goal)
        scheduleSync()
    }

    func delete(_ goal: Goal) throws {
        try local.delete(goal)
        scheduleSync()
    }
}

final class NetworkRecurringTransactionRepository: RecurringTransactionRepository {
    private let local: SwiftDataRecurringTransactionRepository
    private let scheduleSync: () -> Void

    init(context: ModelContext, api: APIClient, scheduleSync: @escaping () -> Void) {
        self.local = SwiftDataRecurringTransactionRepository(context: context)
        self.scheduleSync = scheduleSync
        _ = api
    }

    func fetchAll() throws -> [RecurringTransaction] { try local.fetchAll() }
    func fetch(id: UUID) throws -> RecurringTransaction? { try local.fetch(id: id) }

    func save(_ item: RecurringTransaction) throws {
        try local.save(item)
        scheduleSync()
    }

    func delete(_ item: RecurringTransaction) throws {
        try local.delete(item)
        scheduleSync()
    }
}
