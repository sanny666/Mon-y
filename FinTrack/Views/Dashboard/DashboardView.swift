import SwiftUI

struct DashboardView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = DashboardViewModel()
    @State private var showAddTransaction = false
    @State private var showVoiceCapture = false
    @State private var voiceDraft: VoiceTransactionDraft?
    @State private var voiceErrorMessage: String?
    @State private var isLoading = true
    @State private var editingTransaction: Transaction?
    var onOpenTransactions: () -> Void = {}
    var onOpenAnalytics: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Greeting.title()).font(.title2.bold())
                            Text(dynamicTypeSize.isAccessibilitySize ? Date.now.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "ru_RU"))) : Greeting.subtitle())
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        ProfileButton(diameter: 44)
                    }
                    .padding(.vertical, 8)

                    if let error = viewModel.errorMessage {
                        MoneyCard { MoneyLoadError(message: error, retry: reload) }
                    }

                    if viewModel.errorMessage == nil {
                        BalanceHeroCard(
                            totalBalance: viewModel.totalBalance,
                            monthIncome: viewModel.monthIncome,
                            monthExpense: viewModel.monthExpense,
                            balancePoints: viewModel.balancePoints,
                            currencyCode: viewModel.currencyCode
                        )

                        MoneyPeriodSummary(
                            todayIncome: viewModel.todayIncome,
                            todayExpense: viewModel.todayExpense,
                            weekIncome: viewModel.weekIncome,
                            weekExpense: viewModel.weekExpense,
                            monthIncome: viewModel.monthIncome,
                            monthExpense: viewModel.monthExpense,
                            currencyCode: viewModel.currencyCode
                        )

                        recentSection

                        HealthExpenseChart(
                            points: viewModel.expenseTrend,
                            currencyCode: viewModel.currencyCode,
                            onOpenDetails: onOpenAnalytics
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(MoneyPalette.canvas)
            .overlay {
                if isLoading {
                    MoneyDashboardSkeleton()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background(MoneyPalette.canvas)
                        .allowsHitTesting(false)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isLoading {
                    MoneyActionBar(add: { showAddTransaction = true }, voice: { showVoiceCapture = true })
                }
            }
            .sheet(item: $editingTransaction, onDismiss: reload) { transaction in
                TransactionEditorView(transaction: transaction)
            }
            .sheet(isPresented: $showAddTransaction) {
                TransactionEditorView(transaction: nil)
            }
            .sheet(isPresented: $showVoiceCapture) {
                VoiceCaptureView { text in
                    handleVoiceTranscript(text)
                }
            }
            .sheet(item: $voiceDraft) { draft in
                VoiceTransactionConfirmView(
                    transcript: draft.transcript,
                    parseResult: draft.parseResult
                )
            }
            .alert("Голосовой ввод", isPresented: Binding(
                get: { voiceErrorMessage != nil },
                set: { if !$0 { voiceErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(voiceErrorMessage ?? "")
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
        MoneyCard {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Последние операции").font(.headline)
                    Button(action: onOpenTransactions) {
                        Label("Все операции", systemImage: "chevron.right")
                    }
                    .foregroundStyle(Color.accentColor)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                        .frame(minHeight: 44)
                }

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
                        Button { editingTransaction = tx } label: {
                            MoneyTransactionRow(transaction: tx, currencyCode: tx.account?.currency ?? viewModel.currencyCode)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Изменить операцию")
                        if index < viewModel.recentTransactions.count - 1 {
                            Divider()
                                .opacity(0.6)
                        }
                    }
                }
            }
        }
    }

    private func handleVoiceTranscript(_ text: String) {
        do {
            let result = try container.parseVoiceTranscript(text)
            voiceDraft = VoiceTransactionDraft(transcript: text, parseResult: result)
        } catch {
            voiceErrorMessage = error.localizedDescription
        }
    }

    private func reload() {
        viewModel.reload(container: container, defaultCurrency: defaultCurrency)
    }
}
