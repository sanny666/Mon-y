import SwiftUI

struct AccountsView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel = AccountsViewModel()
    @State private var showAdd = false
    @State private var accountToDelete: Account?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ListSkeleton(rows: 5)
            } else if viewModel.accounts.isEmpty {
                EmptyStateView(
                    systemImage: "creditcard",
                    title: "Нет счетов",
                    subtitle: "Создайте счёт, чтобы учитывать деньги",
                    actionTitle: "Добавить счёт",
                    action: { showAdd = true }
                )
            } else {
                List {
                    ForEach(viewModel.accounts, id: \.id) { account in
                        NavigationLink {
                            AccountDetailView(account: account)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: account.icon)
                                    .foregroundStyle(Color(hex: account.colorHex))
                                    .frame(width: 36, height: 36)
                                    .background(Color(hex: account.colorHex).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.name)
                                        .font(.body.weight(.medium))
                                    Text(account.type.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(CurrencyFormatter.string(
                                    amount: viewModel.balances[account.id] ?? account.initialBalance,
                                    currencyCode: account.currency
                                ))
                                .fontWeight(.semibold)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            accountToDelete = viewModel.accounts[index]
                        }
                    }
                }
                .appGroupedList()
            }
        }
        .navigationTitle("Счета")
        .toolbarTitleDisplayMode(.large)
        .glassAddFAB(
            isVisible: !isLoading,
            accessibilityLabel: "Новый счёт"
        ) {
            showAdd = true
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                AccountEditorView(account: nil)
            }
        }
        .confirmationDialog(
            "Удалить счёт?",
            isPresented: Binding(
                get: { accountToDelete != nil },
                set: { if !$0 { accountToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                if let account = accountToDelete {
                    viewModel.delete(account, container: container)
                }
                accountToDelete = nil
            }
            Button("Отмена", role: .cancel) {
                accountToDelete = nil
            }
        } message: {
            Text("Удалятся все связанные транзакции.")
        }
        .onAppear { FirstLoad.finish($isLoading) { viewModel.reload(container: container) } }
        .onChange(of: container.refreshToken) { _, _ in
            guard !isLoading else { return }
            viewModel.reload(container: container)
        }
        .onChange(of: showAdd) { _, isPresented in
            if !isPresented { viewModel.reload(container: container) }
        }
    }
}

struct AccountDetailView: View {
    @Environment(AppContainer.self) private var container
    @State var account: Account
    @State private var transactions: [Transaction] = []
    @State private var balance: Double = 0
    @State private var showEdit = false
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                AccountDetailSkeleton()
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(CurrencyFormatter.string(amount: balance, currencyCode: account.currency))
                                .font(.largeTitle.bold())
                            Text("\(account.type.title) · \(account.currency)")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Section("История") {
                        if transactions.isEmpty {
                            Text("Нет транзакций по этому счёту")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(transactions, id: \.id) { tx in
                                TransactionRowView(transaction: tx, currencyCode: account.currency)
                            }
                        }
                    }
                }
                .appGroupedList()
            }
        }
        .navigationTitle(account.name)
        .toolbarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !isLoading {
                    Button("Изменить") { showEdit = true }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                AccountEditorView(account: account)
            }
        }
        .onAppear { FirstLoad.finish($isLoading, reload) }
        .onChange(of: container.refreshToken) { _, _ in
            guard !isLoading else { return }
            reload()
        }
        .onChange(of: showEdit) { _, isPresented in
            if !isPresented { reload() }
        }
    }

    private func reload() {
        balance = container.balanceService.balance(for: account)
        do {
            transactions = try container.transactions.fetch(accountID: account.id)
        } catch {
            transactions = []
        }
    }
}

struct AccountEditorView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue

    let account: Account?

    @State private var name = ""
    @State private var type: AccountType = .card
    @State private var currency = AppCurrency.kzt.rawValue
    @State private var balanceText = "0"
    @State private var icon = "creditcard.fill"
    @State private var colorHex = "#268F6B"
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Название", text: $name)
                Picker("Тип", selection: $type) {
                    ForEach(AccountType.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                Picker("Валюта", selection: $currency) {
                    ForEach(AppCurrency.allCases) { item in
                        Text(item.title).tag(item.rawValue)
                    }
                }
                TextField("Начальный баланс", text: $balanceText)
                    .keyboardType(.decimalPad)
            }
            Section {
                IconColorPicker(icon: $icon, colorHex: $colorHex, icons: IconPalette.accountIcons)
            }
        }
        .navigationTitle(account == nil ? "Новый счёт" : "Счёт")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ModalCloseToolbarItem { dismiss() }
            ModalConfirmToolbarItem(isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty) {
                save()
            }
        }
        .onAppear {
            if let account {
                name = account.name
                type = account.type
                currency = account.currency
                balanceText = String(format: "%g", account.initialBalance)
                icon = account.icon
                colorHex = account.colorHex
            } else {
                currency = defaultCurrency
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

    private func save() {
        let balance = Double(balanceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        do {
            if let account {
                account.name = name
                account.type = type
                account.currency = currency
                account.initialBalance = balance
                account.icon = icon
                account.colorHex = colorHex
                try container.accounts.save(account)
            } else {
                let item = Account(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: type,
                    currency: currency,
                    initialBalance: balance,
                    icon: icon,
                    colorHex: colorHex
                )
                try container.accounts.save(item)
            }
            container.notifyChange()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
