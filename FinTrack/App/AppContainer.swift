import Foundation
import Observation
import SwiftData

@Observable
final class AppContainer {
    let accounts: AccountRepository
    let categories: CategoryRepository
    let transactions: TransactionRepository
    let budgets: BudgetRepository
    let goals: GoalRepository
    let recurring: RecurringTransactionRepository
    let balanceService: BalanceService
    let budgetService: BudgetService
    let analyticsService: AnalyticsService
    let recurringService: RecurringService

    private let context: ModelContext
    var refreshToken: Int = 0
    private var periodicMaintenanceTask: Task<Void, Never>?

    init(context: ModelContext) {
        self.context = context
        self.accounts = SwiftDataAccountRepository(context: context)
        self.categories = SwiftDataCategoryRepository(context: context)
        self.transactions = SwiftDataTransactionRepository(context: context)
        self.budgets = SwiftDataBudgetRepository(context: context)
        self.goals = SwiftDataGoalRepository(context: context)
        self.recurring = SwiftDataRecurringTransactionRepository(context: context)
        self.balanceService = BalanceService()
        self.budgetService = BudgetService()
        self.analyticsService = AnalyticsService()
        self.recurringService = RecurringService()
        startPeriodicMaintenance()
    }

    func notifyChange() {
        refreshToken += 1
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
            notifyChange()
        } catch {
            // Keep UI responsive; errors surface via empty data.
        }
    }


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

    func handleSceneBecameActive() {
        processDueRecurring()
    }

    private func startPeriodicMaintenance() {
        periodicMaintenanceTask?.cancel()
        periodicMaintenanceTask = Task { [weak self] in
            while !Task.isCancelled {
                let ns = UInt64(5 * 60 * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                guard !Task.isCancelled else { return }
                self?.processDueRecurring()
            }
        }
    }

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

    /// One-time upgrade: attach default subcategories to existing root categories by name.
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
