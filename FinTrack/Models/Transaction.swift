import Foundation
import SwiftData

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var typeRaw: String
    var date: Date
    var note: String
    var tagsCSV: String = ""
    /// Remote HTTPS URL after upload, or local `file://` path while offline.
    var attachmentURL: String?
    var updatedAt: Date = Date.now
    var isSynced: Bool = false
    var isDeleted: Bool = false
    var serverID: String?

    var account: Account?
    var toAccount: Account?
    var category: Category?

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var tags: [String] {
        get {
            tagsCSV
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            tagsCSV = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
        }
    }

    init(
        id: UUID = UUID(),
        amount: Double,
        type: TransactionType,
        date: Date = .now,
        note: String = "",
        tagsCSV: String = "",
        account: Account? = nil,
        toAccount: Account? = nil,
        category: Category? = nil,
        attachmentURL: String? = nil,
        updatedAt: Date = .now,
        isSynced: Bool = false,
        isDeleted: Bool = false,
        serverID: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.typeRaw = type.rawValue
        self.date = date
        self.note = note
        self.tagsCSV = tagsCSV
        self.account = account
        self.toAccount = toAccount
        self.category = category
        self.attachmentURL = attachmentURL
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.isDeleted = isDeleted
        self.serverID = serverID
    }
}
