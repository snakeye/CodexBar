import XCTest
@testable import CodexBar

final class CodexUsageServiceTests: XCTestCase {
    func testDecodeUsageParsesPayload() throws {
        let json = """
        {
          "rate_limit": {
            "limit_reached": false,
            "primary_window": {
              "used_percent": 42,
              "limit_window_seconds": 18000,
              "reset_after_seconds": 1200,
              "reset_at": 1710000000
            },
            "secondary_window": {
              "used_percent": 10,
              "limit_window_seconds": 604800,
              "reset_after_seconds": 7200,
              "reset_at": null
            }
          }
        }
        """

        let usage = try CodexUsageService.decodeUsage(from: Data(json.utf8))

        XCTAssertFalse(usage.limitReached)
        XCTAssertEqual(usage.primaryWindow.usedPercent, 42)
        XCTAssertEqual(usage.primaryWindow.limitWindowSeconds, 18_000)
        XCTAssertEqual(usage.primaryWindow.resetAfterSeconds, 1_200)
        XCTAssertEqual(usage.primaryWindow.resetAt, 1_710_000_000)
        XCTAssertEqual(usage.secondaryWindow.usedPercent, 10)
        XCTAssertEqual(usage.secondaryWindow.limitWindowSeconds, 604_800)
        XCTAssertEqual(usage.secondaryWindow.resetAfterSeconds, 7_200)
        XCTAssertNil(usage.secondaryWindow.resetAt)
    }

    func testDecodeUsageThrowsOnInvalidPayload() {
        let invalidJSON = Data("{}".utf8)

        XCTAssertThrowsError(try CodexUsageService.decodeUsage(from: invalidJSON))
    }
}
