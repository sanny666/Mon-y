import Foundation
import SwiftData

@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    var limitAmount: Double
    var periodRaw: String
    var currentSpent: Double
    var updatedAt: Date = Date.now
    var isSynced: Bool = false
    var isDeleted: Bool = false
    var serverID: String?

    var category: Category?

    var period: BudgetPeriod {
        get { BudgetPeriod(rawValue: periodRaw) ?? .monthly }
        set { periodRaw = newValue.rawValue }
    }

    var progress: Double {
        guard limitAmount > 0 else { return 0 }
        return min(currentSpent / limitAmount, 1)
    }

    init(
        id: UUID = UUID(),
        category: Category? = nil,
        limitAmount: Double,
        period: BudgetPeriod = .monthly,
        currentSpent: Double = 0,
        updatedAt: Date = .now,
        isSynced: Bool = false,
        isDeleted: Bool = false,
        serverID: String? = nil
    ) {
        self.id = id
        self.category = category
        self.limitAmount = limitAmount
        self.periodRaw = period.rawValue
        self.currentSpent = currentSpent
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.isDeleted = isDeleted
        self.serverID = serverID
    }
}
