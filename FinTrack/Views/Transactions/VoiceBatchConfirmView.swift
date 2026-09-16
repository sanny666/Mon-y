import SwiftUI

struct VoiceDraftItem: Identifiable, Hashable {
    let id: UUID
    var parseResult: VoiceParseResult

    init(id: UUID = UUID(), parseResult: VoiceParseResult) {
        self.id = id
        self.parseResult = parseResult
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: VoiceDraftItem, rhs: VoiceDraftItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct VoiceTransactionDraft: Identifiable {
    let id = UUID()
    let transcript: String
    var items: [VoiceDraftItem]
}

struct VoiceBatchConfirmView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue

    let transcript: String
    @State private var items: [VoiceDraftItem]
    @State private var accounts: [Account] = []
    @State private var categoriesByID: [UUID: Category] = [:]
    @State private var editingItem: VoiceDraftItem?
    @State private var errorMessage: String?

    init(transcript: String, results: [VoiceParseResult]) {
        self.transcript = transcript
        _items = State(initialValue: results.map { VoiceDraftItem(parseResult: $0) })
    }

    init(draft: VoiceTransactionDraft) {
        self.transcript = draft.transcript
        _items = State(initialValue: draft.items)
    }

    private var groupedItems: [(Date, [VoiceDraftItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.parseResult.date)
        }
        return grouped.keys.sorted(by: >).map { key in
            (key, grouped[key] ?? [])
        }
    }

    private var canSave: Bool {
        items.contains { isValid($0.parseResult) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !transcript.isEmpty {
                    Section {
                        Text(transcript)
                            .font(.subheadline.italic())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if items.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Ничего не распознано",
                            systemImage: "waveform.badge.exclamationmark",
                            description: Text("Попробуйте сказать сумму и на что потратили.")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(groupedItems, id: \.0) { date, group in
                        Section(dateTitle(date)) {
                            ForEach(group) { item in
                                Button {
                                    editingItem = item
                                } label: {
                                    VoiceDraftRowView(
                                        item: item.parseResult,
                                        accountName: accountName(for: item.parseResult.accountID),
                                        toAccountName: accountName(for: item.parseResult.toAccountID),
                                        category: category(for: item.parseResult.matchedCategoryID),
                                        currencyCode: currencyCode(for: item.parseResult.accountID)
                                    )
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        items.removeAll { $0.id == item.id }
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(MoneyPalette.canvas)
            .navigationTitle("Подтверждение")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
            .sheet(item: $editingItem) { item in
                VoiceTransactionConfirmView(
                    transcript: "",
                    parseResult: item.parseResult,
                    onApply: { updated in
                        if let index = items.firstIndex(where: { $0.id == item.id }) {
                            items[index].parseResult = updated
                        }
                    }
                )
            }
            .onAppear(perform: loadLookups)
            .alert("Ошибка", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Отмена") {
                dismiss()
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button("Сохранить") {
                saveAll()
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(canSave ? Color(uiColor: .systemBackground) : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                canSave ? Color.primary : Color(uiColor: .tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private func loadLookups() {
        do {
            accounts = try container.accounts.fetchAll()
            let all = try container.categories.fetchAll()
            categoriesByID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func accountName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return accounts.first(where: { $0.id == id })?.name
    }

    private func category(for id: UUID?) -> Category? {
        guard let id else { return nil }
        return categoriesByID[id]
    }

    private func currencyCode(for accountID: UUID?) -> String {
        if let accountID,
           let code = accounts.first(where: { $0.id == accountID })?.currency,
           !code.isEmpty {
            return code
        }
        return defaultCurrency
    }

    private func dateTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Сегодня" }
        if Calendar.current.isDateInYesterday(date) { return "Вчера" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func isValid(_ result: VoiceParseResult) -> Bool {
        guard let amount = result.amount, amount > 0, result.accountID != nil else { return false }
        if result.type == .transfer {
            return result.toAccountID != nil && result.toAccountID != result.accountID
        }
        return true
    }

    private func saveAll() {
        let toSave = items.map(\.parseResult).filter(isValid)
        guard !toSave.isEmpty else { return }

        do {
            for result in toSave {
                guard let amount = result.amount,
                      let accountID = result.accountID,
                      let account = accounts.first(where: { $0.id == accountID }) else { continue }

                let toAccount = accounts.first(where: { $0.id == result.toAccountID })
                let category: Category? = {
                    guard result.type != .transfer,
                          let categoryID = result.matchedCategoryID else { return nil }
                    return categoriesByID[categoryID] ?? (try? container.categories.fetch(id: categoryID))
                }()
                let itemName = result.itemName.trimmingCharacters(in: .whitespacesAndNewlines)

                let item = Transaction(
                    amount: amount,
                    type: result.type,
                    date: result.date,
                    note: result.type == .transfer ? "" : itemName,
                    account: account,
                    toAccount: result.type == .transfer ? toAccount : nil,
                    category: category
                )
                try container.transactions.save(item)

                if result.type != .transfer, !itemName.isEmpty, let category {
                    try container.itemDictionary.upsert(name: itemName, category: category)
                }
            }

            container.recalculateBudgets()
            container.notifyChange()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct VoiceDraftRowView: View {
    let item: VoiceParseResult
    let accountName: String?
    let toAccountName: String?
    let category: Category?
    let currencyCode: String

    private var color: Color {
        item.type == .transfer
            ? .secondary
            : Color(hex: category?.colorHex ?? AppAccent.defaultHex)
    }

    private var title: String {
        if item.type == .transfer { return "Перевод" }
        let note = item.itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? (category?.displayName ?? item.type.title) : note
    }

    private var subtitle: String {
        if item.type == .transfer {
            return [accountName, toAccountName].compactMap { $0 }.joined(separator: " → ")
        }
        return [accountName, category?.displayName].compactMap { $0 }.joined(separator: " · ")
    }

    private var icon: String {
        if item.type == .transfer { return "arrow.left.arrow.right" }
        return category?.icon ?? "creditcard.fill"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            MoneyCategoryIcon(icon: icon, color: color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            amountView
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var amountView: some View {
        let amount = abs(item.amount ?? 0)
        if item.type == .transfer {
            VStack(alignment: .trailing, spacing: 2) {
                Text("−" + CurrencyFormatter.string(amount: amount, currencyCode: currencyCode))
                    .foregroundStyle(MoneyPalette.expense)
                Text("+" + CurrencyFormatter.string(amount: amount, currencyCode: currencyCode))
                    .foregroundStyle(MoneyPalette.income)
            }
            .font(.body.weight(.semibold))
            .monospacedDigit()
        } else {
            let prefix = item.type.increasesAccountBalance ? "+" : "−"
            let color = item.type.increasesAccountBalance ? MoneyPalette.income : MoneyPalette.expense
            Text(prefix + CurrencyFormatter.string(amount: amount, currencyCode: currencyCode))
                .foregroundStyle(color)
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
    }
}
