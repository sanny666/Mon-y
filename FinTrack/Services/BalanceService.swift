import Foundation

struct BalanceService {
    func balance(for account: Account) -> Double {
        var total = account.initialBalance

        for tx in account.transactions {
            switch tx.type {
            case .income:
                total += tx.amount
            case .expense:
                total -= tx.amount
            case .transfer:
                total -= tx.amount
            }
        }

        for tx in account.incomingTransfers where tx.type == .transfer {
            total += tx.amount
        }

        return total
    }

    func totalBalance(accounts: [Account]) -> Double {
        accounts.reduce(0) { $0 + balance(for: $1) }
    }

    func monthIncome(transactions: [Transaction], in date: Date = .now) -> Double {
        let range = Calendar.current.dateInterval(of: .month, for: date)
        return transactions
            .filter { $0.type == .income && (range?.contains($0.date) ?? false) }
            .reduce(0) { $0 + $1.amount }
    }

    func monthExpense(transactions: [Transaction], in date: Date = .now) -> Double {
        let range = Calendar.current.dateInterval(of: .month, for: date)
        return transactions
            .filter { $0.type == .expense && (range?.contains($0.date) ?? false) }
            .reduce(0) { $0 + $1.amount }
    }
}

struct BudgetService {
    private let calendar = Calendar.current

    func recalculateSpent(for budget: Budget, transactions: [Transaction], around date: Date = .now) {
        guard let category = budget.category,
              let range = calendar.dateInterval(of: .month, for: date) else {
            budget.currentSpent = 0
            return
        }

        let matchingIDs = category.matchingIDs
        budget.currentSpent = transactions
            .filter {
                $0.type == .expense
                    && ($0.category.map { matchingIDs.contains($0.id) } ?? false)
                    && range.contains($0.date)
            }
            .reduce(0) { $0 + $1.amount }
    }

    func recalculateAll(budgets: [Budget], transactions: [Transaction]) {
        for budget in budgets {
            recalculateSpent(for: budget, transactions: transactions)
        }
    }
}
