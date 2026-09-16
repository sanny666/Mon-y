import Foundation
import SwiftData

final class SwiftDataAccountRepository: AccountRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Account? {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func save(_ account: Account) throws {
        if account.modelContext == nil {
            context.insert(account)
        }
        account.updatedAt = .now
        account.isSynced = false
        try context.save()
    }

    func delete(_ account: Account) throws {
        account.isDeleted = true
        account.updatedAt = .now
        account.isSynced = false
        try context.save()
    }
}

final class SwiftDataCategoryRepository: CategoryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Category? {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func fetch(type: CategoryType) throws -> [Category] {
        let raw = type.rawValue
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.typeRaw == raw && $0.isDeleted == false },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func fetchRoots() throws -> [Category] {
        try fetchAll().filter { $0.parent == nil }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func fetchRoots(type: CategoryType) throws -> [Category] {
        try fetchRoots().filter { $0.type == type }
    }

    func fetchChildren(of parent: Category) throws -> [Category] {
        parent.children
            .filter { !$0.isDeleted }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func save(_ category: Category) throws {
        if category.modelContext == nil {
            context.insert(category)
        }
        category.updatedAt = .now
        category.isSynced = false
        try context.save()
    }

    func delete(_ category: Category) throws {
        category.isDeleted = true
        category.updatedAt = .now
        category.isSynced = false
        try context.save()
    }
}

final class SwiftDataTransactionRepository: TransactionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Transaction? {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func fetchRecent(limit: Int) throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func fetch(accountID: UUID) throws -> [Transaction] {
        try fetchAll().filter { $0.account?.id == accountID || $0.toAccount?.id == accountID }
    }

    func fetch(filter: TransactionFilter) throws -> [Transaction] {
        var items = try fetchAll()

        if let accountID = filter.accountID {
            items = items.filter { $0.account?.id == accountID || $0.toAccount?.id == accountID }
        }
        if filter.uncategorizedOnly {
            items = items.filter { $0.category == nil }
        } else if let categoryID = filter.categoryID {
            let allCategories = try context.fetch(
                FetchDescriptor<Category>(predicate: #Predicate { $0.isDeleted == false })
            )
            var matchingIDs: Set<UUID> = [categoryID]
            if let selected = allCategories.first(where: { $0.id == categoryID }) {
                matchingIDs.formUnion(selected.matchingIDs)
            }
            items = items.filter { tx in
                guard let cid = tx.category?.id else { return false }
                return matchingIDs.contains(cid)
            }
        }
        if let start = filter.startDate {
            items = items.filter { $0.date >= start }
        }
        if let end = filter.endDate {
            items = items.filter { $0.date <= end }
        }

        let query = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            let lowered = query.lowercased()
            items = items.filter { tx in
                tx.note.lowercased().contains(lowered)
                    || String(format: "%.2f", tx.amount).contains(lowered)
                    || String(Int(tx.amount)).contains(lowered)
            }
        }

        return items
    }

    func save(_ transaction: Transaction) throws {
        if transaction.modelContext == nil {
            context.insert(transaction)
        }
        transaction.updatedAt = .now
        transaction.isSynced = false
        try context.save()
    }

    func delete(_ transaction: Transaction) throws {
        transaction.isDeleted = true
        transaction.updatedAt = .now
        transaction.isSynced = false
        try context.save()
    }
}

final class SwiftDataBudgetRepository: BudgetRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Budget] {
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.limitAmount, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Budget? {
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func save(_ budget: Budget) throws {
        if budget.modelContext == nil {
            context.insert(budget)
        }
        budget.updatedAt = .now
        budget.isSynced = false
        try context.save()
    }

    func delete(_ budget: Budget) throws {
        budget.isDeleted = true
        budget.updatedAt = .now
        budget.isSynced = false
        try context.save()
    }
}

final class SwiftDataGoalRepository: GoalRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Goal? {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func save(_ goal: Goal) throws {
        if goal.modelContext == nil {
            context.insert(goal)
        }
        goal.updatedAt = .now
        goal.isSynced = false
        try context.save()
    }

    func delete(_ goal: Goal) throws {
        goal.isDeleted = true
        goal.updatedAt = .now
        goal.isSynced = false
        try context.save()
    }
}

final class SwiftDataDebtRepository: DebtRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Debt] {
        let descriptor = FetchDescriptor<Debt>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.personName)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Debt? {
        let descriptor = FetchDescriptor<Debt>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func save(_ debt: Debt) throws {
        if debt.modelContext == nil {
            context.insert(debt)
        }
        debt.updatedAt = .now
        debt.isSynced = false
        try context.save()
    }

    func delete(_ debt: Debt) throws {
        debt.isDeleted = true
        debt.updatedAt = .now
        debt.isSynced = false
        try context.save()
    }
}

final class SwiftDataRecurringTransactionRepository: RecurringTransactionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [RecurringTransaction] {
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.nextDate)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> RecurringTransaction? {
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate { $0.id == id && $0.isDeleted == false }
        )
        return try context.fetch(descriptor).first
    }

    func save(_ item: RecurringTransaction) throws {
        if item.modelContext == nil {
            context.insert(item)
        }
        item.updatedAt = .now
        item.isSynced = false
        try context.save()
    }

    func delete(_ item: RecurringTransaction) throws {
        item.isDeleted = true
        item.updatedAt = .now
        item.isSynced = false
        try context.save()
    }
}

final class SwiftDataItemDictionaryRepository: ItemDictionaryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [ItemDictionaryEntry] {
        let descriptor = FetchDescriptor<ItemDictionaryEntry>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.canonicalName)]
        )
        return try context.fetch(descriptor)
    }

    func findExactMatch(for name: String) throws -> ItemDictionaryEntry? {
        let normalized = VoiceStringMatching.normalizeItemName(name)
        guard !normalized.isEmpty else { return nil }

        let entries = try fetchAll()
        if let canonical = entries.first(where: { $0.canonicalName == normalized }) {
            return canonical
        }
        return entries.first { $0.aliases.contains(normalized) }
    }

    func findMatch(for name: String) throws -> ItemDictionaryEntry? {
        let normalized = VoiceStringMatching.normalizeItemName(name)
        guard !normalized.isEmpty else { return nil }

        if let exact = try findExactMatch(for: normalized) {
            return exact
        }

        let stemmed = VoiceStringMatching.stem(normalized)
        guard stemmed.count >= 4 else { return nil }

        let entries = try fetchAll()
        var best: (entry: ItemDictionaryEntry, distance: Int)?

        for entry in entries {
            let candidates = [entry.canonicalName] + entry.aliases
            for candidate in candidates {
                guard candidate.count >= 4 else { continue }
                let candidateStem = VoiceStringMatching.stem(candidate)
                guard candidateStem.count >= 4 else { continue }
                let distance = VoiceStringMatching.levenshteinDistance(stemmed, candidateStem)
                let maxLength = max(stemmed.count, candidateStem.count)
                let threshold = maxLength <= 5 ? 1 : max(1, Int(Double(maxLength) * 0.25))
                guard distance > 0, distance <= threshold else { continue }

                if let current = best {
                    if distance < current.distance
                        || (distance == current.distance && entry.usageCount > current.entry.usageCount) {
                        best = (entry, distance)
                    }
                } else {
                    best = (entry, distance)
                }
            }
        }

        return best?.entry
    }

    func upsert(name: String, category: Category) throws {
        try applyLearning(name: name, category: category, bumpUsage: true)
    }

    func learn(name: String, category: Category) throws {
        try applyLearning(name: name, category: category, bumpUsage: false)
    }

    private func applyLearning(name: String, category: Category, bumpUsage: Bool) throws {
        let normalized = VoiceStringMatching.normalizeItemName(name)
        guard !normalized.isEmpty else { return }

        let entries = try fetchAll()
        if let existing = entries.first(where: { $0.canonicalName == normalized }) {
            let categoryChanged = existing.category?.id != category.id
            existing.category = category
            if bumpUsage {
                existing.usageCount += 1
                existing.lastUsedAt = .now
            }
            guard categoryChanged || bumpUsage else { return }
            existing.updatedAt = .now
            existing.isSynced = false
            try context.save()
            return
        }

        for entry in entries where entry.aliases.contains(normalized) {
            var aliases = entry.aliases
            aliases.removeAll { $0 == normalized }
            entry.aliases = aliases
            entry.updatedAt = .now
            entry.isSynced = false
        }

        let entry = ItemDictionaryEntry(canonicalName: normalized, category: category)
        context.insert(entry)
        entry.updatedAt = .now
        entry.isSynced = false
        if bumpUsage {
            entry.usageCount = 1
            entry.lastUsedAt = .now
        }
        try context.save()
    }

    func insertSeed(name: String, aliases: [String], category: Category) throws {
        let normalized = VoiceStringMatching.normalizeItemName(name)
        guard !normalized.isEmpty else { return }

        let entries = try fetchAll()
        let takenNames = Set(entries.map(\.canonicalName))
        let normalizedAliases = aliases
            .map { VoiceStringMatching.normalizeItemName($0) }
            .filter { !$0.isEmpty && $0 != normalized && !takenNames.contains($0) }

        if let existing = entries.first(where: { $0.canonicalName == normalized }) {
            var changed = false
            if existing.category == nil {
                existing.category = category
                changed = true
            }
            var merged = existing.aliases
            for alias in normalizedAliases where !merged.contains(alias) && !takenNames.contains(alias) {
                merged.append(alias)
                changed = true
            }
            if changed {
                existing.aliases = merged
                existing.updatedAt = .now
                existing.isSynced = false
                try context.save()
            }
            return
        }

        let entry = ItemDictionaryEntry(
            canonicalName: normalized,
            aliasesCSV: normalizedAliases.joined(separator: ","),
            category: category
        )
        context.insert(entry)
        entry.updatedAt = .now
        entry.isSynced = false
        try context.save()
    }
}
