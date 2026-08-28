import SwiftUI

enum MainTab: Hashable {
    case home
    case transactions
    case analytics
    case more
}

struct MainTabView: View {
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
                DashboardView(
                    onOpenTransactions: { selectedTab = .transactions },
                    onOpenAnalytics: { selectedTab = .analytics }
                )
                    .tabItem {
                        Label("Главная", systemImage: "house")
                    }
                    .tag(MainTab.home)

                TransactionsView()
                    .tabItem {
                        Label("Транзакции", systemImage: "list.bullet.rectangle")
                    }
                    .tag(MainTab.transactions)

                NavigationStack {
                    AnalyticsView()
                }
                .tabItem {
                    Label("Аналитика", systemImage: "chart.xyaxis.line")
                }
                .tag(MainTab.analytics)

                MoreView()
                    .tabItem {
                        Label("Ещё", systemImage: "ellipsis.circle")
                    }
                    .tag(MainTab.more)
        }
    }
}
