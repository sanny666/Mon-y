import SwiftUI

struct DebtsView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = DebtsViewModel()
    @State private var isLoading = true
    @State private var createDirection: DebtDirection?
    @State private var selectedDebt: Debt?

    var body: some View {
        Group {
            if isLoading {
                ListSkeleton(rows: 4, kind: .progress)
            } else if viewModel.debts.isEmpty {
                EmptyStateView(
                    systemImage: "person.2",
                    title: "Нет долгов",
                    subtitle: "Отмечайте, кому дали и у кого взяли",
                    actionTitle: "Добавить долг"
                ) {
                    createDebtMenu
                }
            } else {
                List {
                    if !viewModel.openTheyOwe.isEmpty {
                        Section("Мне должны") {
                            ForEach(viewModel.openTheyOwe, id: \.id) { debt in
                                debtButton(debt)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    viewModel.delete(viewModel.openTheyOwe[index], container: container)
                                }
                            }
                        }
                    }
                    if !viewModel.openIOwe.isEmpty {
                        Section("Я должен") {
                            ForEach(viewModel.openIOwe, id: \.id) { debt in
                                debtButton(debt)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    viewModel.delete(viewModel.openIOwe[index], container: container)
                                }
                            }
                        }
                    }
                    if !viewModel.closed.isEmpty {
                        Section("Закрытые") {
                            ForEach(viewModel.closed, id: \.id) { debt in
                                debtButton(debt)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    viewModel.delete(viewModel.closed[index], container: container)
                                }
                            }
                        }
                    }
                }
                .appGroupedList()
            }
        }
        .background(MoneyPalette.canvas)
        .navigationTitle("Долги")
        .toolbarTitleDisplayMode(.large)
        .glassAddFAB(isVisible: !isLoading, accessibilityLabel: "Новый долг") {
            createDebtMenu
        }
        .sheet(item: $createDirection) { direction in
            NavigationStack { DebtEditorView(direction: direction) }
        }
        .sheet(item: $selectedDebt) { debt in
            NavigationStack { DebtDetailView(debt: debt) }
        }
        .onAppear { FirstLoad.finish($isLoading) { viewModel.reload(container: container) } }
        .onChange(of: container.refreshToken) { _, _ in
            guard !isLoading else { return }
            viewModel.reload(container: container)
        }
        .onChange(of: createDirection) { _, value in
            if value == nil { viewModel.reload(container: container) }
        }
        .onChange(of: selectedDebt) { _, value in
            if value == nil { viewModel.reload(container: container) }
        }
    }

    private func debtButton(_ debt: Debt) -> some View {
        Button {
            selectedDebt = debt
        } label: {
            MoneyProgressSummary(
                title: debt.personName,
                icon: debt.icon,
                color: Color(hex: debt.colorHex),
                current: CurrencyFormatter.string(amount: debt.remainingAmount, currencyCode: defaultCurrency),
                target: CurrencyFormatter.string(amount: debt.originalAmount, currencyCode: defaultCurrency),
                progress: debt.progress,
                status: debtStatus(debt)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var createDebtMenu: some View {
        Button("Взял в долг") { createDirection = .iOwe }
        Button("Дал в долг") { createDirection = .theyOwe }
    }

    private func debtStatus(_ debt: Debt) -> String {
        if debt.isClosed { return "Закрыт · \(debt.direction.title)" }
        let left = CurrencyFormatter.string(amount: debt.remainingAmount, currencyCode: defaultCurrency)
        return "\(debt.direction.title) · осталось \(left)"
    }
}

extension Debt: Identifiable {}
extension DebtDirection: Hashable {}

struct DebtEditorView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue

    let direction: DebtDirection

    @State private var personName = ""
    @State private var amountText = ""
    @State private var note = ""
    @State private var date = Date.now
    @State private var hasDueDate = false
    @State private var dueDate = Date.now.addingTimeInterval(86400 * 30)
    @State private var accounts: [Account] = []
    @State private var selectedAccountID: UUID?
    @State private var icon = "person.fill"
    @State private var colorHex = "#C45C26"
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text(direction.openActionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Кто", text: $personName)
                    .textInputAutocapitalization(.words)
                TextField("Сумма · \(defaultCurrency)", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                if accounts.count > 1 {
                    Picker("Счёт", selection: $selectedAccountID) {
                        ForEach(accounts, id: \.id) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }
                } else if let account = accounts.first {
                    LabeledContent("Счёт", value: account.name)
                }
                DatePicker("Дата", selection: $date, displayedComponents: [.date, .hourAndMinute])
                Toggle("Срок возврата", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("До", selection: $dueDate, displayedComponents: .date)
                }
                TextField("Заметка", text: $note)
            }
            Section {
                IconColorPicker(icon: $icon, colorHex: $colorHex, icons: IconPalette.categoryIcons)
            }
        }
        .appGroupedList()
        .background(MoneyPalette.canvas)
        .navigationTitle(direction.openActionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ModalCloseToolbarItem { dismiss() }
            ModalConfirmToolbarItem(isDisabled: !canSave) { save() }
        }
        .onAppear(perform: load)
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canSave: Bool {
        !personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
            && selectedAccountID != nil
    }

    private func load() {
        do {
            accounts = try container.accounts.fetchAll()
            selectedAccountID = DefaultAccountResolver.resolvedID(from: accounts)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard let accountID = selectedAccountID,
              let account = accounts.first(where: { $0.id == accountID }) else {
            errorMessage = "Выберите счёт"
            return
        }
        do {
            _ = try DebtService.open(
                direction: direction,
                personName: personName,
                amount: amount,
                account: account,
                date: date,
                note: note,
                dueDate: hasDueDate ? dueDate : nil,
                icon: icon,
                colorHex: colorHex,
                debts: container.debts,
                transactions: container.transactions
            )
            container.notifyChange()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DebtDetailView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue

    @Bindable var debt: Debt
    @State private var showSettle = false
    @State private var errorMessage: String?

    private var history: [Transaction] {
        debt.transactions
            .filter { !$0.isDeleted }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                MoneyProgressSummary(
                    title: debt.personName,
                    icon: debt.icon,
                    color: Color(hex: debt.colorHex),
                    current: CurrencyFormatter.string(amount: debt.remainingAmount, currencyCode: defaultCurrency),
                    target: CurrencyFormatter.string(amount: debt.originalAmount, currencyCode: defaultCurrency),
                    progress: debt.progress,
                    status: debt.isClosed ? "Закрыт" : debt.direction.title
                )
                if let due = debt.dueDate {
                    LabeledContent("Срок") {
                        Text(due, format: .dateTime.day().month().year())
                    }
                }
                if !debt.note.isEmpty {
                    Text(debt.note).foregroundStyle(.secondary)
                }
            }
            if !history.isEmpty {
                Section("История") {
                    ForEach(history, id: \.id) { tx in
                        MoneyTransactionRow(transaction: tx, currencyCode: defaultCurrency)
                    }
                }
            }
        }
        .appGroupedList()
        .background(MoneyPalette.canvas)
        .navigationTitle(debt.personName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ModalCloseToolbarItem { dismiss() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !debt.isClosed {
                Button {
                    showSettle = true
                } label: {
                    Text(debt.direction.settleActionTitle)
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 48)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.primary)
                        .background(Color(hex: debt.colorHex).opacity(MoneyLayout.accentPillFill), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(6)
                .moneyGlassCapsule()
                .frame(maxWidth: 340)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showSettle) {
            NavigationStack { DebtSettleView(debt: debt) }
        }
        .onChange(of: showSettle) { _, isPresented in
            if !isPresented { container.notifyChange() }
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

struct DebtSettleView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue

    let debt: Debt

    @State private var amountText = ""
    @State private var note = ""
    @State private var date = Date.now
    @State private var accounts: [Account] = []
    @State private var selectedAccountID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text(debt.direction.settleActionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                LabeledContent("Остаток") {
                    Text(CurrencyFormatter.string(amount: debt.remainingAmount, currencyCode: defaultCurrency))
                        .monospacedDigit()
                }
                TextField("Сумма · \(defaultCurrency)", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                if accounts.count > 1 {
                    Picker("Счёт", selection: $selectedAccountID) {
                        ForEach(accounts, id: \.id) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }
                } else if let account = accounts.first {
                    LabeledContent("Счёт", value: account.name)
                }
                DatePicker("Дата", selection: $date, displayedComponents: [.date, .hourAndMinute])
                TextField("Заметка", text: $note)
            }
        }
        .appGroupedList()
        .background(MoneyPalette.canvas)
        .navigationTitle(debt.direction.settleActionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ModalCloseToolbarItem { dismiss() }
            ModalConfirmToolbarItem(isDisabled: !canSave) { save() }
        }
        .onAppear(perform: load)
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canSave: Bool {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        return amount > 0 && amount <= debt.remainingAmount + 0.000_001 && selectedAccountID != nil
    }

    private func load() {
        do {
            accounts = try container.accounts.fetchAll()
            selectedAccountID = DefaultAccountResolver.resolvedID(from: accounts)
            if amountText.isEmpty {
                amountText = String(format: "%g", debt.remainingAmount)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard let accountID = selectedAccountID,
              let account = accounts.first(where: { $0.id == accountID }) else {
            errorMessage = "Выберите счёт"
            return
        }
        do {
            try DebtService.settle(
                debt: debt,
                amount: amount,
                account: account,
                date: date,
                note: note,
                debts: container.debts,
                transactions: container.transactions
            )
            container.notifyChange()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
