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

    private let context: ModelContext
    var refreshToken: Int = 0

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
