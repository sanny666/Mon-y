import SwiftUI

struct MainTabView: View {
    @State private var showAddTransaction = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                DashboardView()
                    .tabItem {
                        Label("Главная", systemImage: "house.fill")
                    }

                TransactionsView()
                    .tabItem {
                        Label("Транзакции", systemImage: "list.bullet.rectangle")
                    }

                AccountsView()
                    .tabItem {
                        Label("Счета", systemImage: "creditcard.fill")
                    }

                MoreView()
                    .tabItem {
                        Label("Ещё", systemImage: "ellipsis.circle.fill")
                    }
            }

            Button {
                showAddTransaction = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color(hex: "#268F6B"))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 72)
            .accessibilityLabel("Новая транзакция")
        }
        .sheet(isPresented: $showAddTransaction) {
            TransactionEditorView(transaction: nil)
        }
    }
}
