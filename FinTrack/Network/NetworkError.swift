import Foundation

enum NetworkError: Error, LocalizedError {
    case unimplemented(endpoint: String)
    case notAuthenticated
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unimplemented(let endpoint):
            return "Network stub: \(endpoint) is not implemented yet"
        case .notAuthenticated:
            return "Not authenticated"
        case .keychain(let status):
            return "Keychain error: \(status)"
        }
    }
}
