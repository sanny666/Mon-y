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

    func dayIncome(transactions: [Transaction], in date: Date = .now) -> Double {
        sum(transactions, type: .income, inDayOf: date)
    }

    func dayExpense(transactions: [Transaction], in date: Date = .now) -> Double {
        sum(transactions, type: .expense, inDayOf: date)
    }

    private func sum(_ transactions: [Transaction], type: TransactionType, inDayOf date: Date) -> Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return transactions
            .filter { $0.type == type && $0.date >= start && $0.date < end }
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

    /// Recalculates spent and evaluates 80%/100% notification thresholds.
    /// Returns budgets whose notification flags changed (need dirty sync markers).
    func recalculateAll(budgets: [Budget], transactions: [Transaction]) -> [Budget] {
        var dirty: [Budget] = []
        for budget in budgets {
            recalculateSpent(for: budget, transactions: transactions)
            if evaluateThresholds(for: budget) {
                dirty.append(budget)
            }
        }
        return dirty
    }

    /// Updates `notifiedAt80` / `notifiedAt100`, fires local notifications once per threshold.
    /// Returns `true` if flags changed.
    ///
    /// Flag reset when `spendRatio < 0.8` is an intentional compromise (not a dedicated
    /// period boundary): deleting/editing txs mid-month can clear flags and allow a second
    /// notify if spend climbs back over 80%. False positive is preferred over missing a
    /// new-period alert. True period edge is the calendar month in `recalculateSpent`.
    func evaluateThresholds(for budget: Budget) -> Bool {
        let ratio = budget.spendRatio
        var changed = false

        // Intentionally ratio-based (not periodKey): mid-period spend drops also reset flags.
        if ratio < 0.8 {
            if budget.notifiedAt80 || budget.notifiedAt100 {
                budget.notifiedAt80 = false
                budget.notifiedAt100 = false
                changed = true
            }
            return changed
        }

        if ratio < 1.0, budget.notifiedAt100 {
            budget.notifiedAt100 = false
            changed = true
        }

        let name = budget.category?.name ?? "категория"

        if !budget.notifiedAt80 {
            budget.notifiedAt80 = true
            NotificationService.shared.notifyBudgetThreshold(
                categoryName: name,
                percent: 80,
                budgetID: budget.id
            )
            changed = true
        }

        if ratio >= 1.0, !budget.notifiedAt100 {
            budget.notifiedAt100 = true
            NotificationService.shared.notifyBudgetThreshold(
                categoryName: name,
                percent: 100,
                budgetID: budget.id
            )
            changed = true
        }

        return changed
    }
}
