import Foundation

/// Auth + Keychain. Uses raw URLSession for auth endpoints (no refresh recursion).
final class AuthManager {
    private enum Keys {
        static let accessToken = "auth.accessToken"
        static let refreshToken = "auth.refreshToken"
        static let userEmail = "auth.userEmail"
        static let userName = "auth.userName"
    }

    private let keychain: KeychainStore
    private let baseURL: URL
    private let session: URLSession

    private(set) var userEmail: String?
    private(set) var userName: String?

    var onSessionExpired: (() -> Void)?

    init(
        keychain: KeychainStore = KeychainStore(),
        baseURL: URL = AppConfig.baseURL,
        session: URLSession = .shared
    ) {
        self.keychain = keychain
        self.baseURL = baseURL
        self.session = session
        self.userEmail = try? keychain.get(Keys.userEmail)
        self.userName = try? keychain.get(Keys.userName)
    }

    var displayName: String {
        if let userName, !userName.isEmpty { return userName }
        if let userEmail, !userEmail.isEmpty { return userEmail }
        return "Профиль"
    }

    var initials: String {
        let name = userName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty {
            let parts = name.split(whereSeparator: { $0.isWhitespace })
            let letters = parts.prefix(2).compactMap(\.first)
            if !letters.isEmpty {
                return String(letters).uppercased()
            }
        }
        if let first = userEmail?.first {
            return String(first).uppercased()
        }
        return "?"
    }

    var accessToken: String? {
        try? keychain.get(Keys.accessToken)
    }

    var storedRefreshToken: String? {
        try? keychain.get(Keys.refreshToken)
    }

    var isLoggedIn: Bool {
        accessToken != nil && storedRefreshToken != nil
    }

    func login(email: String, password: String) async throws {
        let tokens: AuthTokensDTO = try await postUnauthenticated(
            path: "/v1/auth/login",
            body: LoginRequestDTO(email: email, password: password)
        )
        try persist(tokens)
    }

    func register(email: String, password: String, name: String?) async throws {
        let tokens: AuthTokensDTO = try await postUnauthenticated(
            path: "/v1/auth/register",
            body: RegisterRequestDTO(email: email, password: password, name: name)
        )
        try persist(tokens)
    }

    /// Called by APIClient on 401. Does not go through APIClient (avoids refresh loops).
    func refreshToken() async throws {
        guard let refresh = storedRefreshToken else {
            throw NetworkError.notAuthenticated
        }
        let tokens: AuthTokensDTO = try await postUnauthenticated(
            path: "/v1/auth/refresh",
            body: RefreshRequestDTO(refreshToken: refresh)
        )
        try persist(tokens)
    }

    /// Always clears Keychain; best-effort server logout.
    func logout() async {
        let refresh = storedRefreshToken
        clearLocalSession()
        guard let refresh else { return }
        do {
            try await postUnauthenticatedEmpty(
                path: "/v1/auth/logout",
                body: LogoutRequestDTO(refreshToken: refresh)
            )
        } catch {
            // Offline / server error — local clear already done.
        }
    }

    func handleAuthFailure() {
        clearLocalSession()
        onSessionExpired?()
    }

    func applyUser(_ user: AuthUserDTO) {
        persistUser(email: user.email, name: user.name, overwriteName: true)
    }

    func setLocalName(_ name: String?) {
        persistUser(email: userEmail ?? "", name: name, overwriteName: true)
    }

    private func persist(_ tokens: AuthTokensDTO) throws {
        try keychain.set(tokens.accessToken, forKey: Keys.accessToken)
        try keychain.set(tokens.refreshToken, forKey: Keys.refreshToken)
        let incomingName = tokens.user.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        persistUser(email: tokens.user.email, name: tokens.user.name, overwriteName: !incomingName.isEmpty)
    }

    private func persistUser(email: String, name: String?, overwriteName: Bool) {
        if !email.isEmpty {
            try? keychain.set(email, forKey: Keys.userEmail)
            userEmail = email
        }
        guard overwriteName else { return }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            try? keychain.delete(Keys.userName)
            userName = nil
        } else {
            try? keychain.set(trimmed, forKey: Keys.userName)
            userName = trimmed
        }
    }

    private func clearLocalSession() {
        try? keychain.delete(Keys.accessToken)
        try? keychain.delete(Keys.refreshToken)
        try? keychain.delete(Keys.userEmail)
        try? keychain.delete(Keys.userName)
        userEmail = nil
        userName = nil
    }

    private func postUnauthenticated<Body: Encodable, T: Decodable>(path: String, body: Body) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try APIJSON.encoder.encode(body)
        request.timeoutInterval = 30

        let data: Data
        let http: HTTPURLResponse
        do {
            let (respData, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.transport(URLError(.badServerResponse))
            }
            data = respData
            http = httpResponse
        } catch let error as NetworkError {
            throw error
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain {
                if ns.code == NSURLErrorTimedOut { throw NetworkError.timeout }
                throw NetworkError.noConnection
            }
            throw NetworkError.transport(error)
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = try? APIJSON.decoder.decode(APIErrorBody.self, from: data)
            if http.statusCode == 401 { throw NetworkError.unauthorized }
            if http.statusCode == 422 {
                throw NetworkError.validation(message: body?.message, details: nil)
            }
            throw NetworkError.http(status: http.statusCode, code: body?.code, message: body?.message)
        }
        return try APIJSON.decoder.decode(T.self, from: data)
    }

    private func postUnauthenticatedEmpty<Body: Encodable>(path: String, body: Body) async throws {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try APIJSON.encoder.encode(body)
        request.timeoutInterval = 30
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.transport(URLError(.badServerResponse))
        }
        if (200..<300).contains(http.statusCode) { return }
        let err = try? APIJSON.decoder.decode(APIErrorBody.self, from: data)
        throw NetworkError.http(status: http.statusCode, code: err?.code, message: err?.message)
    }
}
