import Foundation

enum MonyDeepLink {
    static let scheme = "mony"
    static let addTransaction = URL(string: "mony://add")!

    static func isAddTransaction(_ url: URL) -> Bool {
        url.scheme == scheme && (url.host == "add" || url.path == "/add")
    }
}
