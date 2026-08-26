import Foundation

/// Shared URLSession client with Bearer auth + one-shot 401 → refresh → retry.
actor APIClient {
    private let session: URLSession
    private let baseURL: URL

    private var accessTokenProvider: @Sendable () -> String?
    private var refreshHandler: @Sendable () async throws -> Void
    private var onAuthFailure: @Sendable () async -> Void

    private var isRefreshing = false
    private var refreshWaiters: [CheckedContinuation<Void, Error>] = []

    init(
        baseURL: URL = AppConfig.baseURL,
        session: URLSession = .shared,
        accessTokenProvider: @escaping @Sendable () -> String?,
        refreshHandler: @escaping @Sendable () async throws -> Void,
        onAuthFailure: @escaping @Sendable () async -> Void
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessTokenProvider = accessTokenProvider
        self.refreshHandler = refreshHandler
        self.onAuthFailure = onAuthFailure
    }

    func updateHandlers(
        accessTokenProvider: @escaping @Sendable () -> String?,
        refreshHandler: @escaping @Sendable () async throws -> Void,
        onAuthFailure: @escaping @Sendable () async -> Void
    ) {
        self.accessTokenProvider = accessTokenProvider
        self.refreshHandler = refreshHandler
        self.onAuthFailure = onAuthFailure
    }

    // MARK: - Public request helpers

    func get<T: Decodable>(_ path: String, authorized: Bool = true) async throws -> T {
        try await send(path: path, method: "GET", body: nil as EmptyBody?, authorized: authorized)
    }

    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body, authorized: Bool = true) async throws -> T {
        try await send(path: path, method: "POST", body: body, authorized: authorized)
    }

    func patch<Body: Encodable, T: Decodable>(_ path: String, body: Body, authorized: Bool = true) async throws -> T {
        try await send(path: path, method: "PATCH", body: body, authorized: authorized)
    }

    func delete(_ path: String, authorized: Bool = true) async throws {
        let _: EmptyResponse = try await send(
            path: path,
            method: "DELETE",
            body: nil as EmptyBody?,
            authorized: authorized,
            allowEmptyBody: true
        )
    }

    func postEmpty<Body: Encodable>(_ path: String, body: Body, authorized: Bool = true) async throws {
        let _: EmptyResponse = try await send(
            path: path,
            method: "POST",
            body: body,
            authorized: authorized,
            allowEmptyBody: true
        )
    }

    func uploadMultipart<T: Decodable>(
        path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "file"
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        return try await sendRaw(
            path: path,
            method: "POST",
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)",
            authorized: true,
            allowEmptyBody: false,
            isRetry: false
        )
    }

    func downloadData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        if let token = accessTokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NetworkError.transport(URLError(.badServerResponse))
            }
            guard (200..<300).contains(http.statusCode) else {
                throw mapHTTPError(status: http.statusCode, data: data)
            }
            return data
        } catch let error as NetworkError {
            throw error
        } catch {
            throw mapTransport(error)
        }
    }

    // MARK: - Core

    private struct EmptyBody: Encodable {}
    private struct EmptyResponse: Decodable {}

    private func send<Body: Encodable, T: Decodable>(
        path: String,
        method: String,
        body: Body?,
        authorized: Bool,
        allowEmptyBody: Bool = false
    ) async throws -> T {
        let data: Data?
        if let body {
            data = try APIJSON.encoder.encode(body)
        } else {
            data = nil
        }
        return try await sendRaw(
            path: path,
            method: method,
            body: data,
            contentType: body == nil ? nil : "application/json",
            authorized: authorized,
            allowEmptyBody: allowEmptyBody,
            isRetry: false
        )
    }

    private func sendRaw<T: Decodable>(
        path: String,
        method: String,
        body: Data?,
        contentType: String?,
        authorized: Bool,
        allowEmptyBody: Bool,
        isRetry: Bool
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authorized, let token = accessTokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

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
            throw mapTransport(error)
        }

        if http.statusCode == 401, authorized, !isRetry {
            do {
                try await refreshAccessTokenCoalesced()
            } catch {
                await onAuthFailure()
                throw NetworkError.unauthorized
            }
            return try await sendRaw(
                path: path,
                method: method,
                body: body,
                contentType: contentType,
                authorized: authorized,
                allowEmptyBody: allowEmptyBody,
                isRetry: true
            )
        }

        if http.statusCode == 401 {
            await onAuthFailure()
            throw NetworkError.unauthorized
        }

        if !(200..<300).contains(http.statusCode) {
            throw mapHTTPError(status: http.statusCode, data: data)
        }

        if allowEmptyBody, data.isEmpty || http.statusCode == 204 {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
        }

        if data.isEmpty, T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try APIJSON.decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }

    private func refreshAccessTokenCoalesced() async throws {
        if isRefreshing {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                refreshWaiters.append(cont)
            }
            return
        }
        isRefreshing = true
        defer {
            isRefreshing = false
        }
        do {
            try await refreshHandler()
            let waiters = refreshWaiters
            refreshWaiters = []
            waiters.forEach { $0.resume() }
        } catch {
            let waiters = refreshWaiters
            refreshWaiters = []
            waiters.forEach { $0.resume(throwing: error) }
            throw error
        }
    }

    private func mapHTTPError(status: Int, data: Data) -> NetworkError {
        let body = try? APIJSON.decoder.decode(APIErrorBody.self, from: data)
        switch status {
        case 401:
            return .unauthorized
        case 409:
            return .conflict(message: body?.message, serverJSON: data)
        case 422:
            return .validation(message: body?.message, details: nil)
        default:
            return .http(status: status, code: body?.code, message: body?.message)
        }
    }

    private func mapTransport(_ error: Error) -> NetworkError {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorDataNotAllowed:
                return .noConnection
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return .noConnection
            default:
                break
            }
        }
        return .transport(error)
    }
}
