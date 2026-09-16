import SwiftUI

struct VoiceTransactionConfirmView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let transcript: String
    let parseResult: VoiceParseResult
    /// When set, Save updates the draft instead of writing to the database.
    var onApply: ((VoiceParseResult) -> Void)? = nil

    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var date = Date.now
    @State private var note = ""
    @State private var categoryMatchHint: String?
    @State private var selectedAccountID: UUID?
    @State private var selectedToAccountID: UUID?
    @State private var selectedRootCategoryID: UUID?
    @State private var selectedSubcategoryID: UUID?
    @State private var accounts: [Account] = []
    @State private var rootCategories: [Category] = []
    @State private var errorMessage: String?
    @State private var suppressTypeCategoryReset = false

    private var isDraftMode: Bool { onApply != nil }

    private var filteredRoots: [Category] {
        guard type != .transfer else { return [] }
        let needed: CategoryType = type == .income ? .income : .expense
        return rootCategories.filter { $0.type == needed }
    }

    private var selectedRoot: Category? {
        filteredRoots.first(where: { $0.id == selectedRootCategoryID })
    }

    private var subcategories: [Category] {
        (selectedRoot?.children ?? [])
            .filter { !$0.isDeleted }
            .sorted {
                $0.name.localizedCompare($1.name) == .orderedAscending
            }
    }

    private var canSave: Bool {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard amount > 0, selectedAccountID != nil else { return false }
        if type == .transfer {
            return selectedToAccountID != nil && selectedToAccountID != selectedAccountID
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { typePicker }
                if !isDraftMode, !transcript.isEmpty {
                    Section {
                        Text(transcript)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Распознанная фраза")
                    }
                }

                Section {
                    TextField("Сумма", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()

                    if type != .transfer {
                        TextField("На что", text: $note, axis: .vertical)
                            .lineLimit(1...3)
                            .font(.body)
                    }
                }

                Section("Счета") {
                    Picker("Счёт", selection: $selectedAccountID) {
                        Text("Выберите").tag(Optional<UUID>.none)
                        ForEach(accounts, id: \.id) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }

                    if type == .transfer {
                        Picker("Куда", selection: $selectedToAccountID) {
                            Text("Выберите").tag(Optional<UUID>.none)
                            ForEach(accounts.filter { $0.id != selectedAccountID }, id: \.id) { account in
                                Text(account.name).tag(Optional(account.id))
                            }
                        }
                    }
                }

                if type != .transfer {
                    Section {
                        Picker("Категория", selection: $selectedRootCategoryID) {
                            Text("Без категории").tag(Optional<UUID>.none)
                            ForEach(filteredRoots, id: \.id) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                        .onChange(of: selectedRootCategoryID) { oldValue, _ in
                            guard oldValue != nil, !suppressTypeCategoryReset else { return }
                            selectedSubcategoryID = nil
                        }

                        if !subcategories.isEmpty {
                            Picker("Подкатегория", selection: $selectedSubcategoryID) {
                                Text("Без подкатегории").tag(Optional<UUID>.none)
                                ForEach(subcategories, id: \.id) { category in
                                    Text(category.name).tag(Optional(category.id))
                                }
                            }
                        }

                        if let categoryMatchHint {
                            Text(categoryMatchHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Категория")
                    } footer: {
                        Text("Подкатегория необязательна — можно указать только «На что».")
                    }
                }

                Section {
                    DatePicker("Дата", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .appGroupedList()
            .navigationTitle(isDraftMode ? "Редактирование" : "Подтверждение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ModalCloseToolbarItem { dismiss() }
                ModalConfirmToolbarItem(isDisabled: !canSave) { save() }
            }
            .onAppear { load() }
            .onChange(of: type) { _, _ in
                guard !suppressTypeCategoryReset else { return }
                if type == .transfer {
                    selectedRootCategoryID = nil
                    selectedSubcategoryID = nil
                } else if let rootID = selectedRootCategoryID,
                          !filteredRoots.contains(where: { $0.id == rootID }) {
                    selectedRootCategoryID = nil
                    selectedSubcategoryID = nil
                } else {
                    selectedSubcategoryID = nil
                }
                if type != .transfer {
                    selectedToAccountID = nil
                }
            }
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

    private var typePicker: some View {
        MoneyPeriodPicker(title: "Тип операции", values: [TransactionType.expense, .income, .transfer], selection: $type, label: { $0.title })
    }

    private func load() {
        do {
            accounts = try container.accounts.fetchAll()
            rootCategories = try container.categories.fetchRoots()

            suppressTypeCategoryReset = true

            type = parseResult.type
            date = parseResult.date
            note = parseResult.itemName
            categoryMatchHint = parseResult.matchHint

            if let amount = parseResult.amount, amount > 0 {
                if abs(amount.rounded() - amount) < 0.001 {
                    amountText = String(Int(amount.rounded()))
                } else {
                    amountText = String(format: "%.2f", amount)
                }
            }

            selectedAccountID = parseResult.accountID ?? DefaultAccountResolver.resolvedID(from: accounts)
            selectedToAccountID = parseResult.toAccountID

            if let categoryID = parseResult.matchedCategoryID {
                applyCategoryID(categoryID)
            }

            Task { @MainActor in
                suppressTypeCategoryReset = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyCategoryID(_ categoryID: UUID) {
        for root in rootCategories {
            if root.id == categoryID {
                selectedRootCategoryID = root.id
                selectedSubcategoryID = nil
                return
            }
            if let child = root.children.first(where: { $0.id == categoryID && !$0.isDeleted }) {
                selectedRootCategoryID = root.id
                selectedSubcategoryID = child.id
                return
            }
        }

        guard let found = try? container.categories.fetch(id: categoryID) else { return }
        if let parent = found.parent {
            selectedRootCategoryID = parent.id
            selectedSubcategoryID = found.id
        } else {
            selectedRootCategoryID = found.id
            selectedSubcategoryID = nil
        }
    }

    private func resolvedCategory() -> Category? {
        if let subID = selectedSubcategoryID,
           let sub = subcategories.first(where: { $0.id == subID }) {
            return sub
        }
        return selectedRoot
    }

    private func makeUpdatedResult() -> VoiceParseResult {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: "."))
        let itemName = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = type == .transfer ? nil : resolvedCategory()

        return VoiceParseResult(
            type: type,
            amount: amount,
            date: date,
            itemName: type == .transfer ? "" : itemName,
            accountID: selectedAccountID,
            toAccountID: type == .transfer ? selectedToAccountID : nil,
            matchHint: categoryMatchHint,
            matchedCategoryID: category?.id,
            hasExplicitDate: true
        )
    }

    private func save() {
        if let onApply {
            onApply(makeUpdatedResult())
            dismiss()
            return
        }

        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard let accountID = selectedAccountID,
              let account = accounts.first(where: { $0.id == accountID }) else { return }

        let toAccount = accounts.first(where: { $0.id == selectedToAccountID })
        let category = type == .transfer ? nil : resolvedCategory()
        let itemName = note.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let item = Transaction(
                amount: amount,
                type: type,
                date: date,
                note: itemName,
                account: account,
                toAccount: type == .transfer ? toAccount : nil,
                category: category
            )
            try container.transactions.save(item)

            if !itemName.isEmpty, let category {
                try container.itemDictionary.upsert(name: itemName, category: category)
            }

            container.recalculateBudgets()
            container.notifyChange()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
