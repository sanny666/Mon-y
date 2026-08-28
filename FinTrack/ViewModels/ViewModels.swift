import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    var totalBalance: Double = 0
    var monthIncome: Double = 0
    var monthExpense: Double = 0
    var todayIncome: Double = 0
    var todayExpense: Double = 0
    var weekIncome: Double = 0
    var weekExpense: Double = 0
    var recentTransactions: [Transaction] = []
    var expenseTrend: [DailyAmountPoint] = []
    var balancePoints: [BalancePoint] = []
    var currencyCode: String = AppCurrency.kzt.rawValue
    var errorMessage: String?

    func reload(container: AppContainer, defaultCurrency: String) {
        do {
            let accounts = try container.accounts.fetchAll()
            let transactions = try container.transactions.fetchAll()
            totalBalance = container.balanceService.totalBalance(accounts: accounts)
            monthIncome = container.balanceService.monthIncome(transactions: transactions)
            monthExpense = container.balanceService.monthExpense(transactions: transactions)
            todayIncome = container.balanceService.dayIncome(transactions: transactions)
            todayExpense = container.balanceService.dayExpense(transactions: transactions)
            weekIncome = container.balanceService.weekIncome(transactions: transactions)
            weekExpense = container.balanceService.weekExpense(transactions: transactions)
            expenseTrend = container.analyticsService.dailyExpenses(transactions: transactions, days: 7)
            balancePoints = container.analyticsService.balanceSeries(
                accounts: accounts,
                transactions: transactions,
                days: 14
            )
            recentTransactions = try container.transactions.fetchRecent(limit: 5)
            currencyCode = accounts.first?.currency ?? defaultCurrency
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class AnalyticsViewModel {
    var period: AnalyticsPeriod = .month
    var categorySlices: [CategoryExpenseSlice] = []
    var monthComparisons: [MonthIncomeExpense] = []
    var balancePoints: [BalancePoint] = []
    var currencyCode: String = AppCurrency.kzt.rawValue
    var errorMessage: String?

    func reload(container: AppContainer, defaultCurrency: String) {
        do {
            let accounts = try container.accounts.fetchAll()
            let transactions = try container.transactions.fetchAll()
            categorySlices = container.analyticsService.expensesByCategory(
                transactions: transactions,
                period: period
            )
            monthComparisons = container.analyticsService.incomeExpenseByMonth(
                transactions: transactions,
                months: 12
            )
            balancePoints = container.analyticsService.balanceSeries(
                accounts: accounts,
                transactions: transactions,
                days: 90
            )
            currencyCode = accounts.first?.currency ?? defaultCurrency
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class TransactionsViewModel {
    var transactions: [Transaction] = []
    var accounts: [Account] = []
    var categories: [Category] = []
    var selectedAccountID: UUID?
    var selectedCategoryID: UUID?
    var period: PeriodFilter = .all
    var searchText: String = ""
    var errorMessage: String?

    enum PeriodFilter: String, CaseIterable, Identifiable {
        case all
        case week
        case month
        case year

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Всё"
            case .week: return "Неделя"
            case .month: return "Месяц"
            case .year: return "Год"
            }
        }
    }

    var groupedByDate: [(Date, [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { tx in
            calendar.startOfDay(for: tx.date)
        }
        return grouped.keys.sorted(by: >).map { key in
            (key, grouped[key] ?? [])
        }
    }

    func reload(container: AppContainer) {
        do {
            accounts = try container.accounts.fetchAll()
            categories = try container.categories.fetchRoots()

            var filter = TransactionFilter(
                accountID: selectedAccountID,
                categoryID: selectedCategoryID,
                searchText: searchText
            )

            let now = Date.now
            let calendar = Calendar.current
            switch period {
            case .all:
                break
            case .week:
                filter.startDate = calendar.date(byAdding: .day, value: -7, to: now)
            case .month:
                filter.startDate = calendar.dateInterval(of: .month, for: now)?.start
            case .year:
                filter.startDate = calendar.dateInterval(of: .year, for: now)?.start
            }

            transactions = try container.transactions.fetch(filter: filter)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ transaction: Transaction, container: AppContainer) {
        do {
            try container.transactions.delete(transaction)
            container.recalculateBudgets()
            reload(container: container)
            container.notifyChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class AccountsViewModel {
    var accounts: [Account] = []
    var balances: [UUID: Double] = [:]
    var errorMessage: String?

    func reload(container: AppContainer) {
        do {
            accounts = try container.accounts.fetchAll()
            balances = Dictionary(uniqueKeysWithValues: accounts.map {
                ($0.id, container.balanceService.balance(for: $0))
            })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ account: Account, container: AppContainer) {
        do {
            try container.accounts.delete(account)
            reload(container: container)
            container.notifyChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class CategoriesViewModel {
    var categories: [Category] = []
    var errorMessage: String?

    var incomeRoots: [Category] {
        categories.filter { $0.type == .income }
    }

    var expenseRoots: [Category] {
        categories.filter { $0.type == .expense }
    }

    func reload(container: AppContainer) {
        do {
            categories = try container.categories.fetchRoots()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ category: Category, container: AppContainer) {
        do {
            try container.categories.delete(category)
            reload(container: container)
            container.notifyChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class BudgetsViewModel {
    var budgets: [Budget] = []
    var errorMessage: String?

    func reload(container: AppContainer) {
        do {
            container.recalculateBudgets()
            budgets = try container.budgets.fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ budget: Budget, container: AppContainer) {
        do {
            try container.budgets.delete(budget)
            reload(container: container)
            container.notifyChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class GoalsViewModel {
    var goals: [Goal] = []
    var errorMessage: String?

    func reload(container: AppContainer) {
        do {
            goals = try container.goals.fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ goal: Goal, container: AppContainer) {
        do {
            try container.goals.delete(goal)
            reload(container: container)
            container.notifyChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class RecurringViewModel {
    var items: [RecurringTransaction] = []
    var errorMessage: String?

    func reload(container: AppContainer) {
        do {
            items = try container.recurring.fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: RecurringTransaction, container: AppContainer) {
        do {
            NotificationService.shared.cancelRecurringReminder(id: item.id)
            try container.recurring.delete(item)
            reload(container: container)
            container.notifyChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
