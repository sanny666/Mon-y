import SwiftUI

struct GoalsView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = GoalsViewModel()
    @State private var showAdd = false
    @State private var editing: Goal?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ListSkeleton(rows: 4, kind: .progress)
            } else if viewModel.goals.isEmpty {
                EmptyStateView(
                    systemImage: "flag",
                    title: "Нет целей",
                    subtitle: "Создайте цель накопления",
                    actionTitle: "Добавить цель",
                    action: { showAdd = true }
                )
            } else {
                List {
                    ForEach(viewModel.goals, id: \.id) { goal in
                        Button {
                            editing = goal
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: goal.icon)
                                        .foregroundStyle(Color(hex: goal.colorHex))
                                    Text(goal.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                ProgressView(value: goal.progress)
                                    .tint(Color(hex: goal.colorHex))
                                Text("\(CurrencyFormatter.string(amount: goal.currentAmount, currencyCode: defaultCurrency)) из \(CurrencyFormatter.string(amount: goal.targetAmount, currencyCode: defaultCurrency))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.delete(viewModel.goals[index], container: container)
                        }
                    }
                }
                .appGroupedList()
            }
        }
        .navigationTitle("Цели")
        .toolbarTitleDisplayMode(.large)
        .glassAddFAB(isVisible: !isLoading, accessibilityLabel: "Новая цель") {
            showAdd = true
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack { GoalEditorView(goal: nil) }
        }
        .sheet(item: $editing) { goal in
            NavigationStack { GoalEditorView(goal: goal) }
        }
        .onAppear { FirstLoad.finish($isLoading) { viewModel.reload(container: container) } }
        .onChange(of: container.refreshToken) { _, _ in
            guard !isLoading else { return }
            viewModel.reload(container: container)
        }
        .onChange(of: showAdd) { _, isPresented in
            if !isPresented { viewModel.reload(container: container) }
        }
        .onChange(of: editing) { _, value in
            if value == nil { viewModel.reload(container: container) }
        }
    }
}

extension Goal: Identifiable {}

struct GoalEditorView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let goal: Goal?

    @State private var name = ""
    @State private var targetText = ""
    @State private var currentText = "0"
    @State private var hasDeadline = false
    @State private var deadline = Date.now.addingTimeInterval(86400 * 90)
    @State private var icon = "flag.fill"
    @State private var colorHex = "#268F6B"
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Название", text: $name)
                TextField("Цель", text: $targetText)
                    .keyboardType(.decimalPad)
                TextField("Уже накоплено", text: $currentText)
                    .keyboardType(.decimalPad)
                Toggle("Дедлайн", isOn: $hasDeadline)
                if hasDeadline {
                    DatePicker("Дата", selection: $deadline, displayedComponents: .date)
                }
            }
            Section {
                IconColorPicker(icon: $icon, colorHex: $colorHex, icons: IconPalette.categoryIcons)
            }
        }
        .navigationTitle(goal == nil ? "Новая цель" : "Цель")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ModalCloseToolbarItem { dismiss() }
            ModalConfirmToolbarItem(
                isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty
                    || (Double(targetText.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0
            ) {
                save()
            }
        }
        .onAppear {
            if let goal {
                name = goal.name
                targetText = String(format: "%g", goal.targetAmount)
                currentText = String(format: "%g", goal.currentAmount)
                hasDeadline = goal.deadline != nil
                deadline = goal.deadline ?? deadline
                icon = goal.icon
                colorHex = goal.colorHex
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
        let target = Double(targetText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let current = Double(currentText.replacingOccurrences(of: ",", with: ".")) ?? 0
        do {
            if let goal {
                goal.name = name
                goal.targetAmount = target
                goal.currentAmount = current
                goal.deadline = hasDeadline ? deadline : nil
                goal.icon = icon
                goal.colorHex = colorHex
                try container.goals.save(goal)
            } else {
                let item = Goal(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    targetAmount: target,
                    currentAmount: current,
                    deadline: hasDeadline ? deadline : nil,
                    icon: icon,
                    colorHex: colorHex
                )
                try container.goals.save(item)
            }
            container.notifyChange()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
