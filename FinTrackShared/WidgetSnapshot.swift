import Foundation

struct WidgetExpenseItem: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var amountText: String
    var dateText: String
}

struct WidgetSnapshot: Codable, Hashable {
    var balanceText: String
    var currencyCode: String
    var recentExpenses: [WidgetExpenseItem]
    var updatedAt: Date

    static let empty = WidgetSnapshot(
        balanceText: "0 ₸",
        currencyCode: "KZT",
        recentExpenses: [],
        updatedAt: .distantPast
    )
}
