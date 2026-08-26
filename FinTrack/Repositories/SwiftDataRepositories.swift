import Foundation
import SwiftData

final class SwiftDataAccountRepository: AccountRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Account? {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func save(_ account: Account) throws {
        if account.modelContext == nil {
            context.insert(account)
        }
        account.updatedAt = .now
        account.isSynced = false
        try context.save()
    }

    func delete(_ account: Account) throws {
        account.isDeleted = true
        account.updatedAt = .now
        account.isSynced = false
        try context.save()
    }
}

final class SwiftDataCategoryRepository: CategoryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Category? {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func fetch(type: CategoryType) throws -> [Category] {
        let raw = type.rawValue
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.typeRaw == raw && $0.isDeleted == false },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func fetchRoots() throws -> [Category] {
        try fetchAll().filter { $0.parent == nil }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func fetchRoots(type: CategoryType) throws -> [Category] {
        try fetchRoots().filter { $0.type == type }
    }

    func fetchChildren(of parent: Category) throws -> [Category] {
        parent.children
            .filter { !$0.isDeleted }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func save(_ category: Category) throws {
        if category.modelContext == nil {
            context.insert(category)
        }
        category.updatedAt = .now
        category.isSynced = false
        try context.save()
    }

    func delete(_ category: Category) throws {
        category.isDeleted = true
        category.updatedAt = .now
        category.isSynced = false
        try context.save()
    }
}

final class SwiftDataTransactionRepository: TransactionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Transaction? {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func fetchRecent(limit: Int) throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func fetch(accountID: UUID) throws -> [Transaction] {
        try fetchAll().filter { $0.account?.id == accountID || $0.toAccount?.id == accountID }
    }

    func fetch(filter: TransactionFilter) throws -> [Transaction] {
        var items = try fetchAll()

        if let accountID = filter.accountID {
            items = items.filter { $0.account?.id == accountID || $0.toAccount?.id == accountID }
        }
        if let categoryID = filter.categoryID {
            let allCategories = try context.fetch(
                FetchDescriptor<Category>(predicate: #Predicate { $0.isDeleted == false })
            )
            var matchingIDs: Set<UUID> = [categoryID]
            if let selected = allCategories.first(where: { $0.id == categoryID }) {
                matchingIDs.formUnion(selected.matchingIDs)
            }
            items = items.filter { tx in
                guard let cid = tx.category?.id else { return false }
                return matchingIDs.contains(cid)
            }
        }
        if let start = filter.startDate {
            items = items.filter { $0.date >= start }
        }
        if let end = filter.endDate {
            items = items.filter { $0.date <= end }
        }

        let query = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            let lowered = query.lowercased()
            items = items.filter { tx in
                tx.note.lowercased().contains(lowered)
                    || String(format: "%.2f", tx.amount).contains(lowered)
                    || String(Int(tx.amount)).contains(lowered)
            }
        }

        return items
    }

    func save(_ transaction: Transaction) throws {
        if transaction.modelContext == nil {
            context.insert(transaction)
        }
        transaction.updatedAt = .now
        transaction.isSynced = false
        try context.save()
    }

    func delete(_ transaction: Transaction) throws {
        transaction.isDeleted = true
        transaction.updatedAt = .now
        transaction.isSynced = false
        try context.save()
    }
}

final class SwiftDataBudgetRepository: BudgetRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Budget] {
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.limitAmount, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Budget? {
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func save(_ budget: Budget) throws {
        if budget.modelContext == nil {
            context.insert(budget)
        }
        budget.updatedAt = .now
        budget.isSynced = false
        try context.save()
    }

    func delete(_ budget: Budget) throws {
        budget.isDeleted = true
        budget.updatedAt = .now
        budget.isSynced = false
        try context.save()
    }
}

final class SwiftDataGoalRepository: GoalRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Goal? {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func save(_ goal: Goal) throws {
        if goal.modelContext == nil {
            context.insert(goal)
        }
        goal.updatedAt = .now
        goal.isSynced = false
        try context.save()
    }

    func delete(_ goal: Goal) throws {
        goal.isDeleted = true
        goal.updatedAt = .now
        goal.isSynced = false
        try context.save()
    }
}

final class SwiftDataRecurringTransactionRepository: RecurringTransactionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [RecurringTransaction] {
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.nextDate)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> RecurringTransaction? {
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func save(_ item: RecurringTransaction) throws {
        if item.modelContext == nil {
            context.insert(item)
        }
        item.updatedAt = .now
        item.isSynced = false
        try context.save()
    }

    func delete(_ item: RecurringTransaction) throws {
        item.isDeleted = true
        item.updatedAt = .now
        item.isSynced = false
        try context.save()
    }
}
