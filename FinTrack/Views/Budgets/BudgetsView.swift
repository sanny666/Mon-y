import SwiftUI

struct BudgetsView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = BudgetsViewModel()
    @State private var showAdd = false
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ListSkeleton(rows: 4, kind: .progress)
            } else if viewModel.budgets.isEmpty {
                EmptyStateView(
                    systemImage: "chart.pie",
                    title: "Нет бюджетов",
                    subtitle: "Задайте лимит по категории на месяц",
                    actionTitle: "Добавить бюджет",
                    action: { showAdd = true }
                )
            } else {
                List {
                    ForEach(viewModel.budgets, id: \.id) { budget in
                        MoneyProgressSummary(
                            title: budget.category?.name ?? "Категория",
                            icon: budget.category?.icon ?? "tag",
                            color: progressTint(for: budget.spendRatio),
                            current: CurrencyFormatter.string(amount: budget.currentSpent, currencyCode: defaultCurrency),
                            target: CurrencyFormatter.string(amount: budget.limitAmount, currencyCode: defaultCurrency),
                            progress: budget.progress,
                            status: budget.spendRatio >= 1
                                ? "Лимит исчерпан"
                                : "Осталось " + CurrencyFormatter.string(amount: max(budget.limitAmount - budget.currentSpent, 0), currencyCode: defaultCurrency)
                        )
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.delete(viewModel.budgets[index], container: container)
                        }
                    }
                }
                .appGroupedList()
            }
        }
        .background(MoneyPalette.canvas)
        .navigationTitle("Бюджеты")
        .toolbarTitleDisplayMode(.large)
        .glassAddFAB(isVisible: !isLoading, accessibilityLabel: "Новый бюджет") {
            showAdd = true
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack { BudgetEditorView() }
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

    private func progressTint(for ratio: Double) -> Color {
        if ratio >= 1 { return MoneyPalette.expense }
        if ratio >= 0.8 { return .orange }
        return .accentColor
    }
}

struct BudgetEditorView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var categories: [Category] = []
    @State private var selectedCategoryID: UUID?
    @State private var limitText = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Picker("Категория", selection: $selectedCategoryID) {
                    Text("Выберите").tag(Optional<UUID>.none)
                    ForEach(categories, id: \.id) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
                TextField("Лимит", text: $limitText)
                    .keyboardType(.decimalPad)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text("Период: месяц")
                    .foregroundStyle(.secondary)
            }
        }
        .appGroupedList()
        .background(MoneyPalette.canvas)
        .navigationTitle("Новый бюджет")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ModalCloseToolbarItem { dismiss() }
            ModalConfirmToolbarItem(
                isDisabled: selectedCategoryID == nil
                    || (Double(limitText.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0
            ) {
                save()
            }
        }
        .onAppear {
            do {
                categories = try container.categories.fetchRoots(type: .expense)
                selectedCategoryID = categories.first?.id
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

    private func save() {
        let limit = Double(limitText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard let id = selectedCategoryID,
              let category = categories.first(where: { $0.id == id }) else { return }
        do {
            let budget = Budget(category: category, limitAmount: limit)
            try container.budgets.save(budget)
            Task {
                await NotificationService.shared.requestAuthorizationIfNeeded()
            }
            container.recalculateBudgets()
            container.notifyChange()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
