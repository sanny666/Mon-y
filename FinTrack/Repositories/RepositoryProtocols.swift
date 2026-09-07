import Foundation

protocol AccountRepository {
    func fetchAll() throws -> [Account]
    func fetch(id: UUID) throws -> Account?
    func save(_ account: Account) throws
    func delete(_ account: Account) throws
}

protocol CategoryRepository {
    func fetchAll() throws -> [Category]
    func fetch(id: UUID) throws -> Category?
    func fetch(type: CategoryType) throws -> [Category]
    func fetchRoots() throws -> [Category]
    func fetchRoots(type: CategoryType) throws -> [Category]
    func fetchChildren(of parent: Category) throws -> [Category]
    func save(_ category: Category) throws
    func delete(_ category: Category) throws
}

struct TransactionFilter {
    var accountID: UUID?
    var categoryID: UUID?
    /// When true, only transactions with no category (ignores `categoryID`).
    var uncategorizedOnly: Bool = false
    var startDate: Date?
    var endDate: Date?
    var searchText: String = ""
}

protocol TransactionRepository {
    func fetchAll() throws -> [Transaction]
    func fetch(id: UUID) throws -> Transaction?
    func fetchRecent(limit: Int) throws -> [Transaction]
    func fetch(accountID: UUID) throws -> [Transaction]
    func fetch(filter: TransactionFilter) throws -> [Transaction]
    func save(_ transaction: Transaction) throws
    func delete(_ transaction: Transaction) throws
}

protocol BudgetRepository {
    func fetchAll() throws -> [Budget]
    func fetch(id: UUID) throws -> Budget?
    func save(_ budget: Budget) throws
    func delete(_ budget: Budget) throws
}

protocol GoalRepository {
    func fetchAll() throws -> [Goal]
    func fetch(id: UUID) throws -> Goal?
    func save(_ goal: Goal) throws
    func delete(_ goal: Goal) throws
}

protocol RecurringTransactionRepository {
    func fetchAll() throws -> [RecurringTransaction]
    func fetch(id: UUID) throws -> RecurringTransaction?
    func save(_ item: RecurringTransaction) throws
    func delete(_ item: RecurringTransaction) throws
}

protocol ItemDictionaryRepository {
    func fetchAll() throws -> [ItemDictionaryEntry]
    func findMatch(for name: String) throws -> ItemDictionaryEntry?
    func upsert(name: String, category: Category) throws
    func insertSeed(name: String, aliases: [String], category: Category) throws
}
