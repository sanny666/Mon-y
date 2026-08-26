import Foundation

/// Network repository stubs implementing the same protocols as SwiftData*.
/// Not wired into AppContainer — see docs/API_CONTRACT.md §5.
/// Each method throws until HTTP is implemented.

// MARK: - Account

final class NetworkAccountRepository: AccountRepository {
    func fetchAll() throws -> [Account] {
        // TODO: GET /v1/accounts
        throw NetworkError.unimplemented(endpoint: "GET /v1/accounts")
    }

    func fetch(id: UUID) throws -> Account? {
        // TODO: GET /v1/accounts/:id
        _ = id
        throw NetworkError.unimplemented(endpoint: "GET /v1/accounts/:id")
    }

    func save(_ account: Account) throws {
        // TODO: POST /v1/accounts (create) or PATCH /v1/accounts/:id (update)
        _ = account
        throw NetworkError.unimplemented(endpoint: "POST|PATCH /v1/accounts")
    }

    func delete(_ account: Account) throws {
        // TODO: DELETE /v1/accounts/:id
        _ = account
        throw NetworkError.unimplemented(endpoint: "DELETE /v1/accounts/:id")
    }
}

// MARK: - Category

final class NetworkCategoryRepository: CategoryRepository {
    func fetchAll() throws -> [Category] {
        // TODO: GET /v1/categories
        throw NetworkError.unimplemented(endpoint: "GET /v1/categories")
    }

    func fetch(id: UUID) throws -> Category? {
        // TODO: GET /v1/categories/:id
        _ = id
        throw NetworkError.unimplemented(endpoint: "GET /v1/categories/:id")
    }

    func fetch(type: CategoryType) throws -> [Category] {
        // TODO: GET /v1/categories?type=
        _ = type
        throw NetworkError.unimplemented(endpoint: "GET /v1/categories?type=")
    }

    func fetchRoots() throws -> [Category] {
        // TODO: GET /v1/categories?rootsOnly=true
        throw NetworkError.unimplemented(endpoint: "GET /v1/categories?rootsOnly=true")
    }

    func fetchRoots(type: CategoryType) throws -> [Category] {
        // TODO: GET /v1/categories?rootsOnly=true&type=
        _ = type
        throw NetworkError.unimplemented(endpoint: "GET /v1/categories?rootsOnly=true&type=")
    }

    func fetchChildren(of parent: Category) throws -> [Category] {
        // TODO: GET /v1/categories (filter by parentId client-side or dedicated query)
        _ = parent
        throw NetworkError.unimplemented(endpoint: "GET /v1/categories (children of parent)")
    }

    func save(_ category: Category) throws {
        // TODO: POST /v1/categories or PATCH /v1/categories/:id
        _ = category
        throw NetworkError.unimplemented(endpoint: "POST|PATCH /v1/categories")
    }

    func delete(_ category: Category) throws {
        // TODO: DELETE /v1/categories/:id
        _ = category
        throw NetworkError.unimplemented(endpoint: "DELETE /v1/categories/:id")
    }
}

// MARK: - Transaction

final class NetworkTransactionRepository: TransactionRepository {
    func fetchAll() throws -> [Transaction] {
        // TODO: GET /v1/transactions
        throw NetworkError.unimplemented(endpoint: "GET /v1/transactions")
    }

    func fetch(id: UUID) throws -> Transaction? {
        // TODO: GET /v1/transactions/:id
        _ = id
        throw NetworkError.unimplemented(endpoint: "GET /v1/transactions/:id")
    }

    func fetchRecent(limit: Int) throws -> [Transaction] {
        // TODO: GET /v1/transactions?limit=
        _ = limit
        throw NetworkError.unimplemented(endpoint: "GET /v1/transactions?limit=")
    }

    func fetch(accountID: UUID) throws -> [Transaction] {
        // TODO: GET /v1/transactions?accountId=
        _ = accountID
        throw NetworkError.unimplemented(endpoint: "GET /v1/transactions?accountId=")
    }

    func fetch(filter: TransactionFilter) throws -> [Transaction] {
        // TODO: GET /v1/transactions with accountId/categoryId/startDate/endDate query
        _ = filter
        throw NetworkError.unimplemented(endpoint: "GET /v1/transactions (filter)")
    }

    func save(_ transaction: Transaction) throws {
        // TODO: POST /v1/transactions or PATCH /v1/transactions/:id
        // Attachments: POST /v1/transactions/:id/attachment (multipart, max 5MB jpeg/png)
        //             DELETE /v1/transactions/:id/attachment; GET redirects 302 to attachmentURL
        _ = transaction
        throw NetworkError.unimplemented(endpoint: "POST|PATCH /v1/transactions")
    }

    func delete(_ transaction: Transaction) throws {
        // TODO: DELETE /v1/transactions/:id
        _ = transaction
        throw NetworkError.unimplemented(endpoint: "DELETE /v1/transactions/:id")
    }
}

// MARK: - Budget

final class NetworkBudgetRepository: BudgetRepository {
    func fetchAll() throws -> [Budget] {
        // TODO: GET /v1/budgets
        throw NetworkError.unimplemented(endpoint: "GET /v1/budgets")
    }

    func fetch(id: UUID) throws -> Budget? {
        // TODO: GET /v1/budgets/:id
        _ = id
        throw NetworkError.unimplemented(endpoint: "GET /v1/budgets/:id")
    }

    func save(_ budget: Budget) throws {
        // TODO: POST /v1/budgets or PATCH /v1/budgets/:id
        _ = budget
        throw NetworkError.unimplemented(endpoint: "POST|PATCH /v1/budgets")
    }

    func delete(_ budget: Budget) throws {
        // TODO: DELETE /v1/budgets/:id
        _ = budget
        throw NetworkError.unimplemented(endpoint: "DELETE /v1/budgets/:id")
    }
}

// MARK: - Goal

final class NetworkGoalRepository: GoalRepository {
    func fetchAll() throws -> [Goal] {
        // TODO: GET /v1/goals
        throw NetworkError.unimplemented(endpoint: "GET /v1/goals")
    }

    func fetch(id: UUID) throws -> Goal? {
        // TODO: GET /v1/goals/:id
        _ = id
        throw NetworkError.unimplemented(endpoint: "GET /v1/goals/:id")
    }

    func save(_ goal: Goal) throws {
        // TODO: POST /v1/goals or PATCH /v1/goals/:id
        _ = goal
        throw NetworkError.unimplemented(endpoint: "POST|PATCH /v1/goals")
    }

    func delete(_ goal: Goal) throws {
        // TODO: DELETE /v1/goals/:id
        _ = goal
        throw NetworkError.unimplemented(endpoint: "DELETE /v1/goals/:id")
    }
}

// MARK: - RecurringTransaction

final class NetworkRecurringTransactionRepository: RecurringTransactionRepository {
    func fetchAll() throws -> [RecurringTransaction] {
        // TODO: GET /v1/recurring-transactions
        throw NetworkError.unimplemented(endpoint: "GET /v1/recurring-transactions")
    }

    func fetch(id: UUID) throws -> RecurringTransaction? {
        // TODO: GET /v1/recurring-transactions/:id
        _ = id
        throw NetworkError.unimplemented(endpoint: "GET /v1/recurring-transactions/:id")
    }

    func save(_ item: RecurringTransaction) throws {
        // TODO: POST /v1/recurring-transactions or PATCH /v1/recurring-transactions/:id
        _ = item
        throw NetworkError.unimplemented(endpoint: "POST|PATCH /v1/recurring-transactions")
    }

    func delete(_ item: RecurringTransaction) throws {
        // TODO: DELETE /v1/recurring-transactions/:id
        _ = item
        throw NetworkError.unimplemented(endpoint: "DELETE /v1/recurring-transactions/:id")
    }
}
