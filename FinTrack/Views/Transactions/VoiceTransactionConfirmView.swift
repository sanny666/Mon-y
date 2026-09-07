import SwiftUI

struct VoiceTransactionDraft: Identifiable {
    let id = UUID()
    let transcript: String
    let parseResult: VoiceParseResult
}

struct VoiceTransactionConfirmView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let transcript: String
    let parseResult: VoiceParseResult

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

    private var filteredRoots: [Category] {
        guard type != .transfer else { return [] }
        let needed: CategoryType = type == .income ? .income : .expense
        return rootCategories.filter { $0.type == needed }
    }

    private var selectedRoot: Category? {
        filteredRoots.first(where: { $0.id == selectedRootCategoryID })
    }

    private var subcategories: [Category] {
        (selectedRoot?.children ?? []).sorted {
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
                if !transcript.isEmpty {
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
                        .font(.title2.weight(.semibold))
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
                        .onChange(of: selectedRootCategoryID) { _, _ in
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
                    }
                }

                Section {
                    DatePicker("Дата", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Название") {
                    TextField("Товар или описание", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Подтверждение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ModalCloseToolbarItem { dismiss() }
                ModalConfirmToolbarItem(isDisabled: !canSave) { save() }
                ToolbarItem(placement: .principal) {
                    typePicker
                }
            }
            .onAppear { load() }
            .onChange(of: type) { _, _ in
                guard !suppressTypeCategoryReset else { return }
                selectedRootCategoryID = filteredRoots.first?.id
                selectedSubcategoryID = nil
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
        HStack(spacing: 18) {
            ForEach(TransactionType.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        type = item
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(item.title)
                            .font(.subheadline.weight(type == item ? .semibold : .regular))
                            .foregroundStyle(type == item ? .primary : .secondary)
                        Capsule()
                            .fill(type == item ? Color.accentColor : Color.clear)
                            .frame(height: 3)
                            .frame(maxWidth: 36)
                    }
                }
                .buttonStyle(.plain)
            }
        }
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
            if let child = root.children.first(where: { $0.id == categoryID }) {
                selectedRootCategoryID = root.id
                selectedSubcategoryID = child.id
                return
            }
        }
    }

    private func resolvedCategory() -> Category? {
        if let subID = selectedSubcategoryID,
           let sub = subcategories.first(where: { $0.id == subID }) {
            return sub
        }
        return selectedRoot
    }

    private func save() {
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
