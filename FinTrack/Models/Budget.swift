import Foundation
import SwiftData

@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    var limitAmount: Double
    var periodRaw: String
    var currentSpent: Double
    var notifiedAt80: Bool = false
    var notifiedAt100: Bool = false
    var updatedAt: Date = Date.now
    var isSynced: Bool = false
    var isDeleted: Bool = false
    var serverID: String?

    var category: Category?

    var period: BudgetPeriod {
        get { BudgetPeriod(rawValue: periodRaw) ?? .monthly }
        set { periodRaw = newValue.rawValue }
    }

    /// Uncapped ratio for threshold checks and progress tint.
    var spendRatio: Double {
        guard limitAmount > 0 else { return 0 }
        return currentSpent / limitAmount
    }

    var progress: Double {
        min(spendRatio, 1)
    }

    init(
        id: UUID = UUID(),
        category: Category? = nil,
        limitAmount: Double,
        period: BudgetPeriod = .monthly,
        currentSpent: Double = 0,
        notifiedAt80: Bool = false,
        notifiedAt100: Bool = false,
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
        self.notifiedAt80 = notifiedAt80
        self.notifiedAt100 = notifiedAt100
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.isDeleted = isDeleted
        self.serverID = serverID
    }
}
