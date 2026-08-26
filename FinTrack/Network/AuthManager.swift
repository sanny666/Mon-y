import Foundation

/// Auth stub. Stores tokens in Keychain. Not wired into AppContainer yet.
/// See docs/API_CONTRACT.md §2 Auth.
final class AuthManager {
    private enum Keys {
        static let accessToken = "auth.accessToken"
        static let refreshToken = "auth.refreshToken"
    }

    private let keychain: KeychainStore

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    var accessToken: String? {
        try? keychain.get(Keys.accessToken)
    }

    var storedRefreshToken: String? {
        try? keychain.get(Keys.refreshToken)
    }

    var isLoggedIn: Bool {
        accessToken != nil
    }

    /// TODO: POST /v1/auth/login — body `{ email, password }`, store tokens from AuthTokens response.
    func login(email: String, password: String) async throws {
        _ = email
        _ = password
        throw NetworkError.unimplemented(endpoint: "POST /v1/auth/login")
    }

    /// TODO: POST /v1/auth/register — body `{ email, password, name? }`, store tokens from AuthTokens response.
    func register(email: String, password: String, name: String?) async throws {
        _ = email
        _ = password
        _ = name
        throw NetworkError.unimplemented(endpoint: "POST /v1/auth/register")
    }

    /// TODO: POST /v1/auth/refresh — body `{ refreshToken }`, rotate and store new tokens.
    func refreshToken() async throws {
        throw NetworkError.unimplemented(endpoint: "POST /v1/auth/refresh")
    }

    /// Clears Keychain tokens. TODO: also POST /v1/auth/logout with refreshToken when online.
    func logout() async throws {
        try keychain.delete(Keys.accessToken)
        try keychain.delete(Keys.refreshToken)
        // TODO: POST /v1/auth/logout
    }

    /// Persists tokens after a successful auth response (for use once network is implemented).
    func storeTokens(accessToken: String, refreshToken: String) throws {
        try keychain.set(accessToken, forKey: Keys.accessToken)
        try keychain.set(refreshToken, forKey: Keys.refreshToken)
    }
}
