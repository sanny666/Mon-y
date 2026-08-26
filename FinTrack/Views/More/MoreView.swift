import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AnalyticsView()
                    } label: {
                        Label("Аналитика", systemImage: "chart.xyaxis.line")
                    }
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        Label("Категории", systemImage: "tag.fill")
                    }
                    NavigationLink {
                        BudgetsView()
                    } label: {
                        Label("Бюджеты", systemImage: "chart.pie.fill")
                    }
                    NavigationLink {
                        RecurringListView()
                    } label: {
                        Label("Повторяющиеся платежи", systemImage: "arrow.clockwise")
                    }
                    NavigationLink {
                        GoalsView()
                    } label: {
                        Label("Цели накоплений", systemImage: "flag.fill")
                    }
                }

                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Настройки", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("Ещё")
        }
    }
}
