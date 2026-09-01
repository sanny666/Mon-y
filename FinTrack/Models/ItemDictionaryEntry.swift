import Foundation
import SwiftData

@Model
final class ItemDictionaryEntry {
    @Attribute(.unique) var id: UUID
    var canonicalName: String
    var aliasesCSV: String = ""
    var usageCount: Int = 1
    var lastUsedAt: Date = Foundation.Date.now
    var updatedAt: Date = Foundation.Date.now
    var isSynced: Bool = false
    var isDeleted: Bool = false
    var serverID: String?

    var category: Category?

    var aliases: [String] {
        get {
            aliasesCSV
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            aliasesCSV = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
        }
    }

    init(
        id: UUID = UUID(),
        canonicalName: String,
        aliasesCSV: String = "",
        category: Category? = nil,
        usageCount: Int = 1,
        lastUsedAt: Date = .now,
        updatedAt: Date = .now,
        isSynced: Bool = false,
        isDeleted: Bool = false,
        serverID: String? = nil
    ) {
        self.id = id
        self.canonicalName = canonicalName
        self.aliasesCSV = aliasesCSV
        self.category = category
        self.usageCount = usageCount
        self.lastUsedAt = lastUsedAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.isDeleted = isDeleted
        self.serverID = serverID
    }
}
