import SwiftUI

enum MainTab: Hashable {
    case home
    case transactions
    case accounts
    case more
}

struct MainTabView: View {
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
                DashboardView(onOpenTransactions: { selectedTab = .transactions })
                    .tabItem {
                        Label("Главная", systemImage: "house")
                    }
                    .tag(MainTab.home)

                TransactionsView()
                    .tabItem {
                        Label("Транзакции", systemImage: "list.bullet.rectangle")
                    }
                    .tag(MainTab.transactions)

                AccountsView()
                    .tabItem {
                        Label("Счета", systemImage: "creditcard")
                    }
                    .tag(MainTab.accounts)

                MoreView()
                    .tabItem {
                        Label("Ещё", systemImage: "ellipsis.circle")
                    }
                    .tag(MainTab.more)
        }
    }
}
