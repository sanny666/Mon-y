import Foundation

enum NetworkError: Error, LocalizedError {
    case unimplemented(endpoint: String)
    case notAuthenticated
    case keychain(OSStatus)
    case invalidURL
    case http(status: Int, code: String?, message: String?)
    case unauthorized
    case conflict(message: String?, serverJSON: Data?)
    case validation(message: String?, details: String?)
    case decoding(Error)
    case transport(Error)
    case timeout
    case noConnection

    var errorDescription: String? {
        switch self {
        case .unimplemented(let endpoint):
            return "Not implemented: \(endpoint)"
        case .notAuthenticated, .unauthorized:
            return "Требуется вход"
        case .keychain(let status):
            return "Keychain error: \(status)"
        case .invalidURL:
            return "Invalid URL"
        case .http(_, _, let message):
            return message ?? "Ошибка сервера"
        case .conflict(let message, _):
            return message ?? "Конфликт версий"
        case .validation(let message, _):
            return message ?? "Ошибка валидации"
        case .decoding(let error):
            return "Ошибка разбора ответа: \(error.localizedDescription)"
        case .transport(let error):
            return error.localizedDescription
        case .timeout:
            return "Таймаут сети"
        case .noConnection:
            return "Нет сети"
        }
    }

    var isConnectivityFailure: Bool {
        switch self {
        case .timeout, .noConnection, .transport:
            return true
        default:
            return false
        }
    }
}
