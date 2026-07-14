import Foundation

struct UsageWindowPresentation {
    let label: String
    let leftPercent: Int
    let resetRelativeLabel: String
    let resetAbsoluteLabel: String
}

struct CodexUsagePresentation {
    let title: String
    let weeklyWindow: UsageWindowPresentation

    static func make(from usage: CodexUsage, now: Date = Date()) -> CodexUsagePresentation {
        let weeklyWindow = makeWindowPresentation(from: usage.weeklyWindow, now: now)

        return CodexUsagePresentation(
            title: makeTitle(limitReached: usage.limitReached, weeklyLeft: weeklyWindow.leftPercent),
            weeklyWindow: weeklyWindow
        )
    }

    static func makeTitle(limitReached: Bool, weeklyLeft: Int) -> String {
        if limitReached {
            return "LIMIT"
        }

        return "\(weeklyLeft)"
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
