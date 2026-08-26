import SwiftUI

struct TransactionsView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = TransactionsViewModel()
    @State private var showAdd = false
    @State private var editingTransaction: Transaction?
    var embedded: Bool = false

    var body: some View {
        Group {
            if embedded {
                configuredContent
            } else {
                NavigationStack {
                    configuredContent
                }
            }
        }
    }

    private var configuredContent: some View {
        content
            .navigationTitle("Транзакции")
            .searchable(text: $viewModel.searchText, prompt: "Заметка или сумма")
            .sheet(isPresented: $showAdd) {
                TransactionEditorView(transaction: nil)
            }
            .sheet(item: $editingTransaction) { tx in
                TransactionEditorView(transaction: tx)
            }
            .onAppear { reload() }
            .onChange(of: container.refreshToken) { _, _ in reload() }
            .onChange(of: viewModel.searchText) { _, _ in reload() }
            .onChange(of: viewModel.selectedAccountID) { _, _ in reload() }
            .onChange(of: viewModel.selectedCategoryID) { _, _ in reload() }
            .onChange(of: viewModel.period) { _, _ in reload() }
            .onChange(of: showAdd) { _, isPresented in
                if !isPresented { reload() }
            }
            .onChange(of: editingTransaction) { _, value in
                if value == nil { reload() }
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            filters
            if viewModel.transactions.isEmpty {
                EmptyStateView(
                    systemImage: "list.bullet.rectangle",
                    title: "Нет транзакций",
                    subtitle: "Добавьте доход, расход или перевод",
                    actionTitle: "Добавить",
                    action: { showAdd = true }
                )
            } else {
                List {
                    ForEach(viewModel.groupedByDate, id: \.0) { date, items in
                        Section(date.formatted(date: .abbreviated, time: .omitted)) {
                            ForEach(items, id: \.id) { tx in
                                Button {
                                    editingTransaction = tx
                                } label: {
                                    TransactionRowView(
                                        transaction: tx,
                                        currencyCode: tx.account?.currency ?? defaultCurrency
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    viewModel.delete(items[index], container: container)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Picker("Период", selection: $viewModel.period) {
                    ForEach(TransactionsViewModel.PeriodFilter.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                Menu {
                    Button("Все счета") { viewModel.selectedAccountID = nil }
                    ForEach(viewModel.accounts, id: \.id) { account in
                        Button(account.name) { viewModel.selectedAccountID = account.id }
                    }
                } label: {
                    filterChip(
                        title: viewModel.accounts.first(where: { $0.id == viewModel.selectedAccountID })?.name ?? "Счёт"
                    )
                }

                Menu {
                    Button("Все категории") { viewModel.selectedCategoryID = nil }
                    ForEach(viewModel.categories, id: \.id) { category in
                        Button(category.name) { viewModel.selectedCategoryID = category.id }
                    }
                } label: {
                    filterChip(
                        title: viewModel.categories.first(where: { $0.id == viewModel.selectedCategoryID })?.name ?? "Категория"
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }

    private func reload() {
        viewModel.reload(container: container)
    }
}

extension Transaction: Identifiable {}
