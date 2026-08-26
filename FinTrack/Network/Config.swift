import Foundation

/// Runtime API configuration. Override without code changes via:
/// - Scheme env `API_BASE_URL` (e.g. local: `http://192.168.1.10:3020`)
/// - Info.plist `APIBaseURL` from Debug/Release build settings
enum AppConfig {
    static var baseURL: URL {
        if let raw = ProcessInfo.processInfo.environment["API_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        if let raw = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
           !raw.contains("$("),
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "https://moneyback.esl.kz")!
    }

    static let apiPrefix = "/v1"
    static let syncInterval: TimeInterval = 5 * 60
}
