import Foundation

struct UsageWindowPresentation {
    let label: String
    let leftPercent: Int
    let resetRelativeLabel: String
    let resetAbsoluteLabel: String
}

struct CodexUsagePresentation {
    let title: String
    let shortWindow: UsageWindowPresentation
    let weeklyWindow: UsageWindowPresentation

    static func make(from usage: CodexUsage, now: Date = Date()) -> CodexUsagePresentation {
        let shortWindow = makeWindowPresentation(from: usage.primaryWindow, now: now)
        let weeklyWindow = makeWindowPresentation(from: usage.secondaryWindow, now: now)

        return CodexUsagePresentation(
            title: makeTitle(
                limitReached: usage.limitReached,
                shortLeft: shortWindow.leftPercent,
                weeklyLeft: weeklyWindow.leftPercent
            ),
            shortWindow: shortWindow,
            weeklyWindow: weeklyWindow
        )
    }

    static func makeTitle(limitReached: Bool, shortLeft: Int, weeklyLeft: Int) -> String {
        if limitReached {
            return "LIMIT"
        }

        return "\(shortLeft)/\(weeklyLeft)"
    }

    static func makeErrorTitle(for error: CodexUsageError) -> String {
        switch error {
        case .httpStatus(let statusCode):
            return "Codex \(statusCode)"
        case .unauthorized:
            return "Codex 401"
        default:
            return "Codex err"
        }
    }

    private static func makeWindowPresentation(from window: UsageWindow, now: Date) -> UsageWindowPresentation {
        UsageWindowPresentation(
            label: CodexUsageFormatting.windowLengthLabel(seconds: window.limitWindowSeconds),
            leftPercent: max(0, 100 - window.usedPercent),
            resetRelativeLabel: CodexUsageFormatting.resetRelativeLabel(
                resetAt: window.resetAt,
                fallbackSeconds: window.resetAfterSeconds,
                now: now
            ),
            resetAbsoluteLabel: CodexUsageFormatting.resetAbsoluteLabel(
                resetAt: window.resetAt,
                fallbackSeconds: window.resetAfterSeconds,
                now: now
            )
        )
    }
}
