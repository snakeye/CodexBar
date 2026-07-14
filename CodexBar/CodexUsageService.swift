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

    func fetchUsage() async throws -> CodexUsage {
        let auth = try loadAuth()
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
            (data, response) = try await URLSession.shared.data(for: request)
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

    nonisolated static func decodeUsage(from data: Data) throws -> CodexUsage {
        let decoded = try JSONDecoder().decode(UsageResponse.self, from: data)
        return CodexUsage(
            limitReached: decoded.rateLimit.limitReached,
            weeklyWindow: decoded.rateLimit.primaryWindow
        )
    }

    private func loadAuth() throws -> CodexAuth {
        let authURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("auth.json")

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
                accountId: decoded.tokens.accountId
            )
        } catch {
            throw CodexUsageError.authFileInvalid(underlying: error)
        }
    }
}

nonisolated private struct CodexAuth {
    let accessToken: String
    let accountId: String
}

nonisolated private struct AuthFile: Decodable {
    let tokens: AuthTokens
}

nonisolated private struct AuthTokens: Decodable {
    let accessToken: String
    let accountId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case accountId = "account_id"
    }
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
