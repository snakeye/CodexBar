import XCTest
@testable import CodexBar

final class CodexUsagePresentationTests: XCTestCase {
    func testMakeTitle() {
        XCTAssertEqual(
            CodexUsagePresentation.makeTitle(limitReached: true, shortLeft: 10, weeklyLeft: 90),
            "LIMIT"
        )
        XCTAssertEqual(
            CodexUsagePresentation.makeTitle(limitReached: false, shortLeft: 39, weeklyLeft: 88),
            "39/88"
        )
    }

    func testMakeErrorTitle() {
        XCTAssertEqual(CodexUsagePresentation.makeErrorTitle(for: .unauthorized), "Codex 401")
        XCTAssertEqual(CodexUsagePresentation.makeErrorTitle(for: .httpStatus(429)), "Codex 429")
        XCTAssertEqual(
            CodexUsagePresentation.makeErrorTitle(for: .authFileMissing(path: "/tmp/auth.json")),
            "Codex err"
        )
    }

    func testMakeMapsBothWindows() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let tomorrow = Int(now.addingTimeInterval(86_400).timeIntervalSince1970)

        let usage = CodexUsage(
            limitReached: false,
            primaryWindow: UsageWindow(
                usedPercent: 61,
                limitWindowSeconds: 18_000,
                resetAfterSeconds: 600,
                resetAt: nil
            ),
            secondaryWindow: UsageWindow(
                usedPercent: 12,
                limitWindowSeconds: 604_800,
                resetAfterSeconds: 0,
                resetAt: tomorrow
            )
        )

        let presentation = CodexUsagePresentation.make(from: usage, now: now)

        XCTAssertEqual(presentation.title, "39/88")
        XCTAssertEqual(presentation.shortWindow.label, "5h")
        XCTAssertEqual(presentation.shortWindow.leftPercent, 39)
        XCTAssertEqual(presentation.shortWindow.resetRelativeLabel, "in 10m")
        XCTAssertTrue(presentation.shortWindow.resetAbsoluteLabel.contains(":"))
        XCTAssertEqual(presentation.weeklyWindow.label, "Weekly")
        XCTAssertEqual(presentation.weeklyWindow.leftPercent, 88)
        XCTAssertTrue(presentation.weeklyWindow.resetRelativeLabel.contains("in 1d"))
        XCTAssertFalse(presentation.weeklyWindow.resetAbsoluteLabel.contains(":"))
    }
}
