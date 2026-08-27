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
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: budget.category?.icon ?? "tag")
                                    .foregroundStyle(Color(hex: budget.category?.colorHex ?? "#268F6B"))
                                Text(budget.category?.name ?? "Категория")
                                    .font(.headline)
                                Spacer()
                                Text("\(CurrencyFormatter.string(amount: budget.currentSpent, currencyCode: defaultCurrency)) / \(CurrencyFormatter.string(amount: budget.limitAmount, currencyCode: defaultCurrency))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: budget.progress)
                                .tint(progressTint(for: budget.spendRatio))
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.delete(viewModel.budgets[index], container: container)
                        }
                    }
                }
            }
        }
        .navigationTitle("Бюджеты")
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
        if ratio >= 1 { return .red }
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
                Text("Период: месяц")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Новый бюджет")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") { save() }
                    .disabled(selectedCategoryID == nil || (Double(limitText.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0)
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
