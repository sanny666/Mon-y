import SwiftUI

struct DashboardView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = DashboardViewModel()
    @State private var showAddTransaction = false
    @State private var path = NavigationPath()
    @State private var isLoading = true

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isLoading {
                    DashboardSkeleton()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(Greeting.subtitle())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, -4)
                                .accessibilityHidden(true)

                            balanceCard

                            IncomeExpenseDonutCard(
                                title: "Сегодня",
                                systemImage: "sun.max.fill",
                                tint: SemanticIcon.today,
                                income: viewModel.todayIncome,
                                expense: viewModel.todayExpense,
                                currencyCode: viewModel.currencyCode
                            )

                            IncomeExpenseDonutCard(
                                title: "Этот месяц",
                                systemImage: "chart.pie.fill",
                                tint: SemanticIcon.chart,
                                income: viewModel.monthIncome,
                                expense: viewModel.monthExpense,
                                currencyCode: viewModel.currencyCode
                            )

                            HealthExpenseChart(
                                points: viewModel.expenseTrend,
                                currencyCode: viewModel.currencyCode,
                                onOpenDetails: { path.append("analytics") }
                            )

                            recentSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 108)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(Greeting.title())
            .navigationBarTitleDisplayMode(.large)
            .glassAddFAB(
                isVisible: path.isEmpty && !isLoading,
                accessibilityLabel: "Новая транзакция"
            ) {
                showAddTransaction = true
            }
            .sheet(isPresented: $showAddTransaction) {
                TransactionEditorView(transaction: nil)
            }
            .navigationDestination(for: String.self) { value in
                switch value {
                case "allTransactions":
                    TransactionsView(embedded: true)
                case "analytics":
                    AnalyticsView()
                default:
                    EmptyView()
                }
            }
            .onAppear { FirstLoad.finish($isLoading, reload) }
            .onChange(of: container.refreshToken) { _, _ in
                guard !isLoading else { return }
                reload()
            }
            .onChange(of: showAddTransaction) { _, isPresented in
                if !isPresented { reload() }
            }
        }
    }

    private var balanceCard: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Общий баланс")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.string(amount: viewModel.totalBalance, currencyCode: viewModel.currencyCode))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Общий баланс \(CurrencyFormatter.string(amount: viewModel.totalBalance, currencyCode: viewModel.currencyCode))"
        )
    }

    private var recentSection: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                DashboardSectionHeader(
                    title: "Последние",
                    systemImage: "list.bullet.rectangle",
                    tint: SemanticIcon.list,
                    action: { path.append("allTransactions") }
                )

                if viewModel.recentTransactions.isEmpty {
                    EmptyStateView(
                        systemImage: "tray",
                        title: "Пока пусто",
                        subtitle: "Добавьте первую транзакцию",
                        actionTitle: "Добавить",
                        action: { showAddTransaction = true }
                    )
                    .frame(minHeight: 140)
                } else {
                    ForEach(Array(viewModel.recentTransactions.enumerated()), id: \.element.id) { index, tx in
                        TransactionRowView(transaction: tx, currencyCode: viewModel.currencyCode)
                        if index < viewModel.recentTransactions.count - 1 {
                            Divider()
                                .opacity(0.6)
                        }
                    }
                }
            }
        }
    }

    private func reload() {
        viewModel.reload(container: container, defaultCurrency: defaultCurrency)
    }
}
