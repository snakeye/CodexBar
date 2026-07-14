import Foundation

nonisolated struct CodexUsage {
    let limitReached: Bool
    let weeklyWindow: UsageWindow
}

nonisolated struct UsageWindow {
    let usedPercent: Int
    let limitWindowSeconds: Int
    let resetAfterSeconds: Int
    let resetAt: Int?
}

nonisolated enum CodexUsageError: Error {
    case authFileMissing(path: String)
    case authFileUnreadable(underlying: Error)
    case authFileInvalid(underlying: Error)
    case unauthorized
    case httpStatus(Int)
    case invalidResponse
    case decodingFailed(underlying: Error)
    case network(underlying: Error)

    var logMessage: String {
        switch self {
        case .authFileMissing(let path):
            return "Auth file missing at \(path)"
        case .authFileUnreadable(let underlying):
            return "Auth file unreadable: \(underlying.localizedDescription)"
        case .authFileInvalid(let underlying):
            return "Auth file invalid: \(underlying.localizedDescription)"
        case .unauthorized:
            return "Request unauthorized (401)"
        case .httpStatus(let code):
            return "Unexpected HTTP status: \(code)"
        case .invalidResponse:
            return "Invalid non-HTTP response"
        case .decodingFailed(let underlying):
            return "Usage response decoding failed: \(underlying.localizedDescription)"
        case .network(let underlying):
            return "Network request failed: \(underlying.localizedDescription)"
        }
    }
}

actor CodexUsageService {
    private let usageURL = URL(string: "https://chatgpt.com/backend-api/codex/usage")!
    private let tokenURL = URL(string: "https://auth.openai.com/api/accounts/oauth/token")!
    private let session: URLSession
    private let authURL: URL

    init(
        session: URLSession = .shared,
        authURL: URL? = nil
    ) {
        self.session = session
        self.authURL = authURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("auth.json")
    }

    func fetchUsage() async throws -> CodexUsage {
        let auth = try loadAuth()

        do {
            return try await fetchUsage(using: auth)
        } catch CodexUsageError.unauthorized {
            let refreshedAuth = try await refreshAuth(using: auth)
            return try await fetchUsage(using: refreshedAuth)
        }
    }

    private func fetchUsage(using auth: CodexAuth) async throws -> CodexUsage {
        var request = URLRequest(url: usageURL)
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("codex/0.122.0", forHTTPHeaderField: "User-Agent")
        request.setValue("vscode-file://vscode-app", forHTTPHeaderField: "Origin")
        request.setValue("vscode-file://vscode-app/", forHTTPHeaderField: "Referer")
        request.setValue(auth.accountId, forHTTPHeaderField: "ChatGPT-Account-ID")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CodexUsageError.network(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CodexUsageError.invalidResponse
        }

        guard http.statusCode == 200 else {
            if http.statusCode == 401 {
                throw CodexUsageError.unauthorized
            }

            throw CodexUsageError.httpStatus(http.statusCode)
        }

        do {
            return try Self.decodeUsage(from: data)
        } catch {
            throw CodexUsageError.decodingFailed(underlying: error)
        }
    }

    private func refreshAuth(using auth: CodexAuth) async throws -> CodexAuth {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Self.formEncodedBody([
            "grant_type": "refresh_token",
            "refresh_token": auth.refreshToken,
            "client_id": auth.clientId
        ])

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CodexUsageError.network(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CodexUsageError.invalidResponse
        }

        guard http.statusCode == 200 else {
            if http.statusCode == 401 {
                throw CodexUsageError.unauthorized
            }

            throw CodexUsageError.httpStatus(http.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(AuthRefreshResponse.self, from: data)
            let refreshed = CodexAuth(
                accessToken: decoded.accessToken,
                refreshToken: decoded.refreshToken ?? auth.refreshToken,
                accountId: auth.accountId,
                clientId: auth.clientId,
                idToken: decoded.idToken ?? auth.idToken
            )
            try persistAuth(refreshed)
            return refreshed
        } catch {
            throw CodexUsageError.decodingFailed(underlying: error)
        }
    }

    nonisolated static func decodeUsage(from data: Data) throws -> CodexUsage {
        let decoded = try JSONDecoder().decode(UsageResponse.self, from: data)
        return CodexUsage(
            limitReached: decoded.rateLimit.limitReached,
            weeklyWindow: decoded.rateLimit.primaryWindow
        )
    }

    private func loadAuth() throws -> CodexAuth {
        guard FileManager.default.fileExists(atPath: authURL.path) else {
            throw CodexUsageError.authFileMissing(path: authURL.path)
        }

        let data: Data
        do {
            data = try Data(contentsOf: authURL)
        } catch {
            throw CodexUsageError.authFileUnreadable(underlying: error)
        }

        do {
            let decoded = try JSONDecoder().decode(AuthFile.self, from: data)
            return CodexAuth(
                accessToken: decoded.tokens.accessToken,
                refreshToken: decoded.tokens.refreshToken,
                accountId: decoded.tokens.accountId,
                clientId: try Self.extractClientID(from: decoded.tokens.accessToken),
                idToken: decoded.tokens.idToken
            )
        } catch {
            throw CodexUsageError.authFileInvalid(underlying: error)
        }
    }

    private func persistAuth(_ auth: CodexAuth) throws {
        guard FileManager.default.fileExists(atPath: authURL.path) else {
            throw CodexUsageError.authFileMissing(path: authURL.path)
        }

        let data: Data
        do {
            data = try Data(contentsOf: authURL)
        } catch {
            throw CodexUsageError.authFileUnreadable(underlying: error)
        }

        do {
            let root = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
            var mutableRoot = root
            var tokens = (root["tokens"] as? [String: Any]) ?? [:]
            tokens["access_token"] = auth.accessToken
            tokens["refresh_token"] = auth.refreshToken
            tokens["id_token"] = auth.idToken
            tokens["account_id"] = auth.accountId
            mutableRoot["tokens"] = tokens
            mutableRoot["last_refresh"] = Self.iso8601Formatter.string(from: Date())

            let output = try JSONSerialization.data(withJSONObject: mutableRoot, options: [.prettyPrinted, .sortedKeys])
            try output.write(to: authURL, options: [.atomic])
        } catch let error as CodexUsageError {
            throw error
        } catch {
            throw CodexUsageError.authFileInvalid(underlying: error)
        }
    }

    private static func extractClientID(from accessToken: String) throws -> String {
        let segments = accessToken.split(separator: ".")
        guard segments.count >= 2 else {
            throw CodexUsageError.authFileInvalid(underlying: TokenParsingError.invalidJWT)
        }

        let payloadPart = String(segments[1])
        let payloadData = try Self.decodeBase64URL(payloadPart)
        let payload = try JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any] ?? [:]
        guard let clientID = payload["client_id"] as? String, !clientID.isEmpty else {
            throw CodexUsageError.authFileInvalid(underlying: TokenParsingError.missingClientID)
        }
        return clientID
    }

    private static func decodeBase64URL(_ string: String) throws -> Data {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64) else {
            throw CodexUsageError.authFileInvalid(underlying: TokenParsingError.invalidBase64)
        }
        return data
    }

    private static func formEncodedBody(_ values: [String: String]) -> Data {
        let body = values
            .sorted(by: { $0.key < $1.key })
            .map { key, value in
                "\(Self.urlEncode(key))=\(Self.urlEncode(value))"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    private static func urlEncode(_ string: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

nonisolated private struct CodexAuth {
    let accessToken: String
    let refreshToken: String
    let accountId: String
    let clientId: String
    let idToken: String
}

nonisolated private struct AuthFile: Decodable {
    let tokens: AuthTokens
}

nonisolated private struct AuthTokens: Decodable {
    let accessToken: String
    let refreshToken: String
    let accountId: String
    let idToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case accountId = "account_id"
        case idToken = "id_token"
    }
}

nonisolated private struct AuthRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
    }
}

nonisolated private enum TokenParsingError: Error {
    case invalidJWT
    case invalidBase64
    case missingClientID
}

nonisolated private struct UsageResponse: Decodable {
    let rateLimit: RateLimit

    enum CodingKeys: String, CodingKey {
        case rateLimit = "rate_limit"
    }
}

nonisolated private struct RateLimit: Decodable {
    let limitReached: Bool
    let primaryWindow: UsageWindow

    enum CodingKeys: String, CodingKey {
        case allowed
        case limitReached = "limit_reached"
        case primaryWindow = "primary_window"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _ = try container.decode(Bool.self, forKey: .allowed)
        limitReached = try container.decode(Bool.self, forKey: .limitReached)
        primaryWindow = try container.decode(UsageWindow.self, forKey: .primaryWindow)
    }
}

extension UsageWindow: Decodable {
    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case resetAfterSeconds = "reset_after_seconds"
        case resetAt = "reset_at"
    }
}
