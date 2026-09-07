import SwiftUI

struct MoreView: View {
    @Environment(AppContainer.self) private var container
    @State private var showExportEmpty = false
    @State private var exportErrorMessage: String?
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section("Финансы") {
                    NavigationLink {
                        AccountsView()
                    } label: {
                        moreRow("Счета", systemImage: "creditcard", tint: SemanticIcon.goal)
                    }
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        moreRow("Категории", systemImage: "tag.fill", tint: SemanticIcon.tag)
                    }
                    NavigationLink {
                        BudgetsView()
                    } label: {
                        moreRow("Бюджеты", systemImage: "chart.pie.fill", tint: SemanticIcon.budget)
                    }
                    NavigationLink {
                        RecurringListView()
                    } label: {
                        moreRow("Повторяющиеся платежи", systemImage: "arrow.clockwise", tint: SemanticIcon.recurring)
                    }
                    NavigationLink {
                        GoalsView()
                    } label: {
                        moreRow("Цели накоплений", systemImage: "flag.fill", tint: SemanticIcon.goal)
                    }
                    NavigationLink {
                        DebtsView()
                    } label: {
                        moreRow("Долги", systemImage: "person.2.fill", tint: SemanticIcon.debt)
                    }
                }

                Section("Данные") {
                    Button {
                        exportCSV()
                    } label: {
                        moreRow("Экспорт CSV", systemImage: "square.and.arrow.up", tint: SemanticIcon.export)
                    }
                    NavigationLink {
                        BankImportView()
                    } label: {
                        moreRow("Импорт из банка", systemImage: "building.columns", tint: SemanticIcon.bank)
                    }
                }
                Section("Приложение") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        moreRow("Настройки", systemImage: "gearshape.fill", tint: SemanticIcon.settings)
                    }
                }
            }
            .appGroupedList()
            .largeScreenTitle("Ещё", showsProfile: true)
            .alert("Нет данных", isPresented: $showExportEmpty) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Нет транзакций для экспорта.")
            }
            .alert(
                "Ошибка экспорта",
                isPresented: Binding(
                    get: { exportErrorMessage != nil },
                    set: { if !$0 { exportErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "")
            }
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } }
            )) {
                if let shareURL {
                    ActivityShareSheet(items: [shareURL]) {
                        self.shareURL = nil
                    }
                    .presentationDetents([.medium, .large])
                }
            }
        }
    }

    private func moreRow(_ title: String, systemImage: String, tint: Color) -> some View {
        let subtitles = [
            "Счета": "Карты, наличные и депозиты",
            "Категории": "Порядок в доходах и расходах",
            "Бюджеты": "Лимиты по категориям",
            "Повторяющиеся платежи": "Подписки и регулярные расходы",
            "Цели накоплений": "Прогресс к вашим планам",
            "Долги": "Кому дали и у кого взяли",
            "Экспорт CSV": "Сохранить историю операций",
            "Импорт из банка": "Добавить операции из выписки",
            "Настройки": "Оформление, валюта и безопасность"
        ]
        return MoneyEntityRow(title: title, subtitle: subtitles[title], icon: systemImage, color: tint)
    }

    private func exportCSV() {
        do {
            let transactions = try container.transactions.fetchAll()
            let result = try CSVExportService.export(transactions: transactions)
            shareURL = result.fileURL
        } catch CSVExportService.ExportError.noTransactions {
            showExportEmpty = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}
