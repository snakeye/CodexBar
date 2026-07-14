import XCTest
@testable import CodexBar

final class CodexUsageFormattingTests: XCTestCase {
    func testWindowLengthLabel() {
        XCTAssertEqual(CodexUsageFormatting.windowLengthLabel(seconds: 604_800), "Weekly")
        XCTAssertEqual(CodexUsageFormatting.windowLengthLabel(seconds: 1_800), "30m")
        XCTAssertEqual(CodexUsageFormatting.windowLengthLabel(seconds: 45), "45s")
    }

    func testResetAbsoluteLabelUsesTimeForToday() {
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let label = CodexUsageFormatting.resetAbsoluteLabel(resetAt: nil, fallbackSeconds: 600, now: fixedNow)

        XCTAssertEqual(label.count, 5)
        XCTAssertEqual(label[label.index(label.startIndex, offsetBy: 2)], ":")
    }

    func testResetAbsoluteLabelUsesDateForFutureDay() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let resetAt = Int(tomorrow.timeIntervalSince1970)

        let label = CodexUsageFormatting.resetAbsoluteLabel(resetAt: resetAt, fallbackSeconds: 0)
        XCTAssertFalse(label.contains(":"))
    }

    func testResetRelativeLabelForMinutes() {
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let label = CodexUsageFormatting.resetRelativeLabel(resetAt: nil, fallbackSeconds: 600, now: fixedNow)

        XCTAssertEqual(label, "in 10m")
    }

    func testResetRelativeLabelForHourAndMinutes() {
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let label = CodexUsageFormatting.resetRelativeLabel(resetAt: nil, fallbackSeconds: 5_400, now: fixedNow)

        XCTAssertEqual(label, "in 1h 30m")
    }

    func testResetRelativeLabelForDaysAndHours() {
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let label = CodexUsageFormatting.resetRelativeLabel(resetAt: nil, fallbackSeconds: 172_800, now: fixedNow)

        XCTAssertEqual(label, "in 2d")
    }
}
