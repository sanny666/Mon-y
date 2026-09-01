import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var typeRaw: String
    var updatedAt: Date = Date.now
    var isSynced: Bool = false
    var isDeleted: Bool = false
    var serverID: String?

    var parent: Category?

    @Relationship(deleteRule: .cascade, inverse: \Category.parent)
    var children: [Category] = []

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []

    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budgets: [Budget] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.category)
    var recurringTemplates: [RecurringTransaction] = []

    @Relationship(deleteRule: .nullify, inverse: \ItemDictionaryEntry.category)
    var dictionaryEntries: [ItemDictionaryEntry] = []

    var type: CategoryType {
        get { CategoryType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var isSubcategory: Bool { parent != nil }

    var displayName: String {
        if let parent {
            return "\(parent.name) · \(name)"
        }
        return name
    }

    /// IDs of this category and all direct children (for budgets/filters).
    var matchingIDs: Set<UUID> {
        var ids: Set<UUID> = [id]
        for child in children where !child.isDeleted {
            ids.insert(child.id)
        }
        return ids
    }

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorHex: String,
        type: CategoryType,
        parent: Category? = nil,
        updatedAt: Date = .now,
        isSynced: Bool = false,
        isDeleted: Bool = false,
        serverID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.typeRaw = type.rawValue
        self.parent = parent
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.isDeleted = isDeleted
        self.serverID = serverID
    }
}
