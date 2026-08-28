import SwiftUI

struct DashboardView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = DashboardViewModel()
    @State private var showAddTransaction = false
    @State private var isLoading = true
    var onOpenTransactions: () -> Void = {}
    var onOpenAnalytics: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    BalanceHeroCard(
                        totalBalance: viewModel.totalBalance,
                        monthIncome: viewModel.monthIncome,
                        monthExpense: viewModel.monthExpense,
                        balancePoints: viewModel.balancePoints,
                        currencyCode: viewModel.currencyCode
                    )

                    IncomeExpenseDonutCarousel(
                        todayIncome: viewModel.todayIncome,
                        todayExpense: viewModel.todayExpense,
                        weekIncome: viewModel.weekIncome,
                        weekExpense: viewModel.weekExpense,
                        monthIncome: viewModel.monthIncome,
                        monthExpense: viewModel.monthExpense,
                        currencyCode: viewModel.currencyCode
                    )

                    HealthExpenseChart(
                        points: viewModel.expenseTrend,
                        currencyCode: viewModel.currencyCode,
                        onOpenDetails: onOpenAnalytics
                    )

                    recentSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 108)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .overlay {
                if isLoading {
                    DashboardSkeletonContent()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background(Color(uiColor: .systemGroupedBackground))
                        .allowsHitTesting(false)
                }
            }
            .largeScreenTitle(Greeting.title(), subtitle: Greeting.subtitle(), showsProfile: true)
            .glassAddFAB(
                isVisible: !isLoading,
                accessibilityLabel: "Новая транзакция"
            ) {
                showAddTransaction = true
            }
            .sheet(isPresented: $showAddTransaction) {
                TransactionEditorView(transaction: nil)
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

    private var recentSection: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                DashboardSectionHeader(
                    title: "Последние",
                    systemImage: "list.bullet.rectangle",
                    tint: SemanticIcon.list,
                    action: onOpenTransactions
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
