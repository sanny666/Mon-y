import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var currency: String
    var initialBalance: Double
    var icon: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date = Date.now
    var isSynced: Bool = false
    var isDeleted: Bool = false
    var serverID: String?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction] = []

    @Relationship(deleteRule: .nullify, inverse: \Transaction.toAccount)
    var incomingTransfers: [Transaction] = []

    @Relationship(deleteRule: .cascade, inverse: \RecurringTransaction.account)
    var recurringTemplates: [RecurringTransaction] = []

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .cash }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        currency: String,
        initialBalance: Double,
        icon: String = "creditcard.fill",
        colorHex: String = "#268F6B",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isSynced: Bool = false,
        isDeleted: Bool = false,
        serverID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.currency = currency
        self.initialBalance = initialBalance
        self.icon = icon
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.isDeleted = isDeleted
        self.serverID = serverID
    }
}
