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
}
