import Foundation
import SwiftData

@Model
final class Debt {
    @Attribute(.unique) var id: UUID
    var personName: String
    var directionRaw: String
    var originalAmount: Double
    var remainingAmount: Double
    var dueDate: Date?
    var note: String
    var icon: String
    var colorHex: String
    var updatedAt: Date = Date.now
    var isSynced: Bool = false
    var isDeleted: Bool = false
    var serverID: String?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.debt)
    var transactions: [Transaction] = []

    var direction: DebtDirection {
        get { DebtDirection(rawValue: directionRaw) ?? .iOwe }
        set { directionRaw = newValue.rawValue }
    }

    var isClosed: Bool { remainingAmount <= 0.000_001 }

    var progress: Double {
        guard originalAmount > 0 else { return 0 }
        let repaid = originalAmount - max(remainingAmount, 0)
        return min(max(repaid / originalAmount, 0), 1)
    }

    init(
        id: UUID = UUID(),
        personName: String,
        direction: DebtDirection,
        originalAmount: Double,
        remainingAmount: Double? = nil,
        dueDate: Date? = nil,
        note: String = "",
        icon: String = "person.fill",
        colorHex: String = "#C45C26",
        updatedAt: Date = .now,
        isSynced: Bool = false,
        isDeleted: Bool = false,
        serverID: String? = nil
    ) {
        self.id = id
        self.personName = personName
        self.directionRaw = direction.rawValue
        self.originalAmount = originalAmount
        self.remainingAmount = remainingAmount ?? originalAmount
        self.dueDate = dueDate
        self.note = note
        self.icon = icon
        self.colorHex = colorHex
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.isDeleted = isDeleted
        self.serverID = serverID
    }
}
