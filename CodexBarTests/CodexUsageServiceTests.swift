import Foundation
import XCTest
@testable import CodexBar

final class CodexUsageServiceTests: XCTestCase {
    func testDecodeUsageParsesWeeklyPayload() throws {
        let json = """
        {
          "user_id": "user-CIoP9UPhy7kOI3TviGJlBlvz",
          "account_id": "user-CIoP9UPhy7kOI3TviGJlBlvz",
          "email": "andrew.ovcharov@gmail.com",
          "plan_type": "plus",
          "rate_limit": {
            "allowed": true,
            "limit_reached": false,
            "primary_window": {
              "used_percent": 1,
              "limit_window_seconds": 604800,
              "reset_after_seconds": 604045,
              "reset_at": 1784621352
            },
            "secondary_window": null
          },
          "code_review_rate_limit": null,
          "additional_rate_limits": null,
          "credits": {
            "has_credits": false,
            "unlimited": false,
            "overage_limit_reached": false,
            "balance": "0",
            "approx_local_messages": [0, 0],
            "approx_cloud_messages": [0, 0]
          },
          "spend_control": {
            "reached": false,
            "individual_limit": null
          },
          "rate_limit_reached_type": null,
          "promo": null,
          "rate_limit_reset_credits": {
            "available_count": 4
          }
        }
        """

        let usage = try CodexUsageService.decodeUsage(from: Data(json.utf8))

        XCTAssertFalse(usage.limitReached)
        XCTAssertEqual(usage.weeklyWindow.usedPercent, 1)
        XCTAssertEqual(usage.weeklyWindow.limitWindowSeconds, 604_800)
        XCTAssertEqual(usage.weeklyWindow.resetAfterSeconds, 604_045)
        XCTAssertEqual(usage.weeklyWindow.resetAt, 1_784_621_352)
    }

    func testDecodeUsageThrowsOnInvalidPayload() {
        let invalidJSON = Data("{}".utf8)

        XCTAssertThrowsError(try CodexUsageService.decodeUsage(from: invalidJSON))
    }

    func testFetchUsageRefreshesAuthOnUnauthorized() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let codexDirectory = tempDirectory.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let authURL = codexDirectory.appendingPathComponent("auth.json")

        let oldAccessToken = makeJWT(clientID: "app_old_client")
        let newAccessToken = makeJWT(clientID: "app_new_client")
        let oldRefreshToken = "rt.old"
        let newRefreshToken = "rt.new"
        let oldIDToken = makeJWT(clientID: "app_old_client", audience: ["app_old_client"])
        let newIDToken = makeJWT(clientID: "app_new_client", audience: ["app_new_client"])
        try writeAuthFile(
            to: authURL,
            accessToken: oldAccessToken,
            refreshToken: oldRefreshToken,
            idToken: oldIDToken,
            accountID: "account-123"
        )

        let usageURL = URL(string: "https://chatgpt.com/backend-api/codex/usage")!
        let tokenURL = URL(string: "https://auth.openai.com/api/accounts/oauth/token")!
        let session = makeMockSession { request in
            guard let url = request.url else {
                return (self.httpResponse(url: usageURL, statusCode: 500), Data())
            }

            if url == usageURL {
                let authHeader = request.value(forHTTPHeaderField: "Authorization") ?? ""
                if authHeader == "Bearer \(oldAccessToken)" {
                    return (self.httpResponse(url: url, statusCode: 401), Data())
                }

                if authHeader == "Bearer \(newAccessToken)" {
                    return (self.httpResponse(url: url, statusCode: 200), Data(self.makeUsageJSON(usedPercent: 11).utf8))
                }

                return (self.httpResponse(url: url, statusCode: 403), Data())
            }

            if url == tokenURL {
                return (
                    self.httpResponse(url: url, statusCode: 200),
                    Data(
                        self.makeRefreshJSON(
                            accessToken: newAccessToken,
                            refreshToken: newRefreshToken,
                            idToken: newIDToken
                        ).utf8
                    )
                )
            }

            return (self.httpResponse(url: url, statusCode: 404), Data())
        }

        let service = CodexUsageService(session: session, authURL: authURL)
        let usage = try await service.fetchUsage()

        XCTAssertEqual(usage.weeklyWindow.usedPercent, 11)

        let persisted = try readJSON(at: authURL)
        let tokens = persisted["tokens"] as? [String: Any]
        XCTAssertEqual(tokens?["access_token"] as? String, newAccessToken)
        XCTAssertEqual(tokens?["refresh_token"] as? String, newRefreshToken)
        XCTAssertEqual(tokens?["id_token"] as? String, newIDToken)
        XCTAssertEqual(tokens?["account_id"] as? String, "account-123")
        XCTAssertNotNil(persisted["last_refresh"] as? String)
    }

    func testFetchUsageThrowsUnauthorizedWhenRefreshFails() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let codexDirectory = tempDirectory.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let authURL = codexDirectory.appendingPathComponent("auth.json")

        let oldAccessToken = makeJWT(clientID: "app_old_client")
        let oldRefreshToken = "rt.old"
        let oldIDToken = makeJWT(clientID: "app_old_client", audience: ["app_old_client"])
        try writeAuthFile(
            to: authURL,
            accessToken: oldAccessToken,
            refreshToken: oldRefreshToken,
            idToken: oldIDToken,
            accountID: "account-123"
        )
        let before = try Data(contentsOf: authURL)

        let usageURL = URL(string: "https://chatgpt.com/backend-api/codex/usage")!
        let tokenURL = URL(string: "https://auth.openai.com/api/accounts/oauth/token")!
        let session = makeMockSession { request in
            guard let url = request.url else {
                return (self.httpResponse(url: usageURL, statusCode: 500), Data())
            }

            if url == usageURL {
                return (self.httpResponse(url: url, statusCode: 401), Data())
            }

            if url == tokenURL {
                return (self.httpResponse(url: url, statusCode: 401), Data())
            }

            return (self.httpResponse(url: url, statusCode: 404), Data())
        }

        let service = CodexUsageService(session: session, authURL: authURL)

        do {
            _ = try await service.fetchUsage()
            XCTFail("Expected unauthorized error")
        } catch let error as CodexUsageError {
            switch error {
            case .unauthorized:
                break
            default:
                XCTFail("Expected unauthorized error, got \(error)")
            }
        }

        let after = try Data(contentsOf: authURL)
        XCTAssertEqual(after, before)
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension CodexUsageServiceTests {
    func makeMockSession(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
        MockURLProtocol.requestHandler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func httpResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
    }

    func makeUsageJSON(usedPercent: Int) -> String {
        """
        {
          "rate_limit": {
            "allowed": true,
            "limit_reached": false,
            "primary_window": {
              "used_percent": \(usedPercent),
              "limit_window_seconds": 604800,
              "reset_after_seconds": 604045,
              "reset_at": 1784621352
            },
            "secondary_window": null
          }
        }
        """
    }

    func makeRefreshJSON(accessToken: String, refreshToken: String, idToken: String) -> String {
        """
        {
          "access_token": "\(accessToken)",
          "refresh_token": "\(refreshToken)",
          "id_token": "\(idToken)",
          "token_type": "Bearer",
          "scope": "openid profile email offline_access",
          "expires_in": 3600,
          "earliest_refresh_at": 0,
          "oai_is": true
        }
        """
    }

    func makeJWT(clientID: String, audience: [String] = ["https://api.openai.com/v1"]) -> String {
        let header: [String: Any] = ["alg": "RS256", "typ": "JWT"]
        let payload: [String: Any] = [
            "aud": audience,
            "client_id": clientID,
            "iss": "https://auth.openai.com"
        ]
        return [header, payload].map { json in
            let data = try! JSONSerialization.data(withJSONObject: json, options: [])
            return data.base64URLEncodedString()
        }.joined(separator: ".") + ".sig"
    }

    func writeAuthFile(to url: URL, accessToken: String, refreshToken: String, idToken: String, accountID: String) throws {
        let payload: [String: Any] = [
            "OPENAI_API_KEY": NSNull(),
            "tokens": [
                "access_token": accessToken,
                "refresh_token": refreshToken,
                "id_token": idToken,
                "account_id": accountID
            ],
            "last_refresh": "2026-07-12T18:36:14.976559Z"
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: [.atomic])
    }

    func readJSON(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
