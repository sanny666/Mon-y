import SwiftUI

struct DashboardView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = DashboardViewModel()
    @State private var showAddTransaction = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    balanceCard
                    monthSummary
                    chartPlaceholder
                    recentSection
                }
                .padding()
            }
            .navigationTitle("Главная")
            .sheet(isPresented: $showAddTransaction) {
                TransactionEditorView(transaction: nil)
            }
            .navigationDestination(for: String.self) { value in
                if value == "allTransactions" {
                    TransactionsView(embedded: true)
                }
            }
            .onAppear { reload() }
            .onChange(of: container.refreshToken) { _, _ in reload() }
            .onChange(of: showAddTransaction) { _, isPresented in
                if !isPresented { reload() }
            }
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Общий баланс")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(CurrencyFormatter.string(amount: viewModel.totalBalance, currencyCode: viewModel.currencyCode))
                .font(.largeTitle.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var monthSummary: some View {
        HStack(spacing: 12) {
            summaryTile(title: "Доходы", amount: viewModel.monthIncome, color: .green)
            summaryTile(title: "Расходы", amount: viewModel.monthExpense, color: .red)
        }
    }

    private func summaryTile(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(CurrencyFormatter.string(amount: amount, currencyCode: viewModel.currencyCode))
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var chartPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("график скоро")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Последние транзакции")
                    .font(.headline)
                Spacer()
                Button("Все") {
                    path.append("allTransactions")
                }
            }

            if viewModel.recentTransactions.isEmpty {
                EmptyStateView(
                    systemImage: "tray",
                    title: "Пока пусто",
                    subtitle: "Добавьте первую транзакцию",
                    actionTitle: "Добавить",
                    action: { showAddTransaction = true }
                )
                .frame(height: 180)
            } else {
                ForEach(viewModel.recentTransactions, id: \.id) { tx in
                    TransactionRowView(transaction: tx, currencyCode: viewModel.currencyCode)
                }
            }
        }
    }

    private func reload() {
        viewModel.reload(container: container, defaultCurrency: defaultCurrency)
    }
}
