import Foundation

enum MonyDeepLink {
    static let scheme = "mony"
    static let addTransaction = URL(string: "mony://add")!
    static let voiceTransaction = URL(string: "mony://voice")!

    static func isAddTransaction(_ url: URL) -> Bool {
        url.scheme == scheme && (url.host == "add" || url.path == "/add")
    }

    static func isVoiceTransaction(_ url: URL) -> Bool {
        url.scheme == scheme && (url.host == "voice" || url.path == "/voice")
    }
}
