import Foundation
import SwiftData

@Model
final class RecurringTransaction {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var typeRaw: String
    var note: String
    var frequencyRaw: String
    var nextDate: Date
    var updatedAt: Date = Date.now
    var isSynced: Bool = false
    var isDeleted: Bool = false
    var serverID: String?

    var account: Account?
    var category: Category?

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        amount: Double,
        type: TransactionType,
        note: String = "",
        frequency: RecurringFrequency,
        nextDate: Date,
        account: Account? = nil,
        category: Category? = nil,
        updatedAt: Date = .now,
        isSynced: Bool = false,
        isDeleted: Bool = false,
        serverID: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.typeRaw = type.rawValue
        self.note = note
        self.frequencyRaw = frequency.rawValue
        self.nextDate = nextDate
        self.account = account
        self.category = category
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.isDeleted = isDeleted
        self.serverID = serverID
    }
}
