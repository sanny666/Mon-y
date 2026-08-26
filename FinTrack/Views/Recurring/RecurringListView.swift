import SwiftUI

struct RecurringListView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = RecurringViewModel()
    @State private var showAdd = false

    var body: some View {
        Group {
            if viewModel.items.isEmpty {
                EmptyStateView(
                    systemImage: "arrow.clockwise",
                    title: "Нет повторяющихся платежей",
                    subtitle: "Добавьте шаблон регулярного платежа",
                    actionTitle: "Добавить",
                    action: { showAdd = true }
                )
            } else {
                List {
                    ForEach(viewModel.items, id: \.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.note.isEmpty ? item.type.title : item.note)
                                    .font(.headline)
                                Spacer()
                                Text(CurrencyFormatter.string(amount: item.amount, currencyCode: item.account?.currency ?? defaultCurrency))
                                    .fontWeight(.semibold)
                            }
                            Text("\(item.frequency.title) · следующий \(item.nextDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let account = item.account {
                                Text(account.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.delete(viewModel.items[index], container: container)
                        }
                    }
                }
            }
        }
        .navigationTitle("Повторяющиеся")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack { RecurringEditorView() }
        }
        .onAppear { viewModel.reload(container: container) }
        .onChange(of: container.refreshToken) { _, _ in viewModel.reload(container: container) }
        .onChange(of: showAdd) { _, isPresented in
            if !isPresented { viewModel.reload(container: container) }
        }
    }
}

struct RecurringEditorView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var note = ""
    @State private var frequency: RecurringFrequency = .monthly
    @State private var nextDate = Date.now
    @State private var accounts: [Account] = []
    @State private var rootCategories: [Category] = []
    @State private var selectedAccountID: UUID?
    @State private var selectedRootCategoryID: UUID?
    @State private var selectedSubcategoryID: UUID?
    @State private var errorMessage: String?

    private var filteredRoots: [Category] {
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

    var body: some View {
        Form {
            Section {
                TextField("Сумма", text: $amountText)
                    .keyboardType(.decimalPad)
                Picker("Тип", selection: $type) {
                    Text(TransactionType.income.title).tag(TransactionType.income)
                    Text(TransactionType.expense.title).tag(TransactionType.expense)
                }
                .pickerStyle(.segmented)
                .onChange(of: type) { _, _ in
                    selectedRootCategoryID = filteredRoots.first?.id
                    selectedSubcategoryID = nil
                }
                TextField("Заметка", text: $note)
                Picker("Частота", selection: $frequency) {
                    ForEach(RecurringFrequency.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                DatePicker("Следующая дата", selection: $nextDate, displayedComponents: .date)
            }
            Section {
                Picker("Счёт", selection: $selectedAccountID) {
                    Text("Выберите").tag(Optional<UUID>.none)
                    ForEach(accounts, id: \.id) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
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
            }
        }
        .navigationTitle("Новый платёж")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") { save() }
                    .disabled(selectedAccountID == nil || (Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0)
            }
        }
        .onAppear {
            do {
                accounts = try container.accounts.fetchAll()
                rootCategories = try container.categories.fetchRoots()
                selectedAccountID = accounts.first?.id
                selectedRootCategoryID = filteredRoots.first?.id
            } catch {
                errorMessage = error.localizedDescription
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
        do {
            let item = RecurringTransaction(
                amount: amount,
                type: type,
                note: note,
                frequency: frequency,
                nextDate: nextDate,
                account: account,
                category: resolvedCategory()
            )
            try container.recurring.save(item)
            container.notifyChange()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
