import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
                DashboardView()
                    .tabItem {
                        Label("Главная", systemImage: "house")
                    }

                TransactionsView()
                    .tabItem {
                        Label("Транзакции", systemImage: "list.bullet.rectangle")
                    }

                AccountsView()
                    .tabItem {
                        Label("Счета", systemImage: "creditcard")
                    }

                MoreView()
                    .tabItem {
                        Label("Ещё", systemImage: "ellipsis.circle")
                    }
        }
    }
}
