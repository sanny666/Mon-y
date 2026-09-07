import SwiftUI

struct RecurringListView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = RecurringViewModel()
    @State private var showAdd = false
    @State private var editingItem: RecurringTransaction?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ListSkeleton(rows: 5)
            } else if viewModel.items.isEmpty {
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
                        Button {
                            editingItem = item
                        } label: {
                            MoneyEntityRow(
                                title: item.note.isEmpty ? item.type.title : item.note,
                                subtitle: "\(item.frequency.title) · \(item.nextDate.formatted(date: .abbreviated, time: .omitted))" + (item.account.map { " · \($0.name)" } ?? ""),
                                icon: "arrow.clockwise",
                                color: SemanticIcon.recurring,
                                amount: CurrencyFormatter.string(amount: item.amount, currencyCode: item.account?.currency ?? defaultCurrency)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.delete(viewModel.items[index], container: container)
                        }
                    }
                }
                .appGroupedList()
            }
        }
        .background(MoneyPalette.canvas)
        .navigationTitle("Повторяющиеся")
        .toolbarTitleDisplayMode(.large)
        .glassAddFAB(isVisible: !isLoading, accessibilityLabel: "Новый платёж") {
            showAdd = true
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack { RecurringEditorView() }
        }
        .sheet(isPresented: Binding(
            get: { editingItem != nil },
            set: { if !$0 { editingItem = nil; viewModel.reload(container: container) } }
        )) {
            if let editingItem {
                NavigationStack { RecurringEditorView(existing: editingItem) }
            }
        }
        .onAppear {
            FirstLoad.finish($isLoading) {
                viewModel.reload(container: container)
                container.processDueRecurring()
            }
        }
        .onChange(of: container.refreshToken) { _, _ in
            guard !isLoading else { return }
            viewModel.reload(container: container)
        }
        .onChange(of: showAdd) { _, isPresented in
            if !isPresented { viewModel.reload(container: container) }
        }
    }
}

struct RecurringEditorView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    var existing: RecurringTransaction?

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
                TextField("Название", text: $note)
                TextField("Сумма", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Picker("Тип", selection: $type) {
                    Text(TransactionType.income.title).tag(TransactionType.income)
                    Text(TransactionType.expense.title).tag(TransactionType.expense)
                }
                .pickerStyle(.segmented)
                .onChange(of: type) { _, _ in
                    selectedRootCategoryID = filteredRoots.first?.id
                    selectedSubcategoryID = nil
                }
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
        .appGroupedList()
        .background(MoneyPalette.canvas)
        .navigationTitle(existing == nil ? "Новый платёж" : "Платёж")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ModalCloseToolbarItem { dismiss() }
            ModalConfirmToolbarItem(
                isDisabled: selectedAccountID == nil
                    || (Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0
            ) {
                save()
            }
        }
        .onAppear { load() }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() {
        do {
            accounts = try container.accounts.fetchAll()
            rootCategories = try container.categories.fetchRoots()
            if let existing {
                amountText = String(existing.amount)
                type = existing.type
                note = existing.note
                frequency = existing.frequency
                nextDate = existing.nextDate
                selectedAccountID = existing.account?.id ?? accounts.first?.id
                if let category = existing.category {
                    if let parent = category.parent {
                        selectedRootCategoryID = parent.id
                        selectedSubcategoryID = category.id
                    } else {
                        selectedRootCategoryID = category.id
                        selectedSubcategoryID = nil
                    }
                } else {
                    selectedRootCategoryID = filteredRoots.first?.id
                }
            } else {
                selectedAccountID = accounts.first?.id
                selectedRootCategoryID = filteredRoots.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
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
            let item: RecurringTransaction
            if let existing {
                existing.amount = amount
                existing.type = type
                existing.note = note
                existing.frequency = frequency
                existing.nextDate = nextDate
                existing.account = account
                existing.category = resolvedCategory()
                item = existing
            } else {
                item = RecurringTransaction(
                    amount: amount,
                    type: type,
                    note: note,
                    frequency: frequency,
                    nextDate: nextDate,
                    account: account,
                    category: resolvedCategory()
                )
            }
            try container.recurring.save(item)
            Task {
                await NotificationService.shared.requestAuthorizationIfNeeded()
            }
            container.rescheduleRecurringReminder(for: item)
            container.processDueRecurring()
            container.notifyChange()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
