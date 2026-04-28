import Foundation

enum CodexUsageFormatting {
    static func windowLengthLabel(seconds: Int) -> String {
        if seconds == 604_800 { return "Weekly" }

        let hours = seconds / 3600
        if hours > 0 { return "\(hours)h" }

        let minutes = seconds / 60
        if minutes > 0 { return "\(minutes)m" }

        return "\(seconds)s"
    }

    static func resetAbsoluteLabel(resetAt: Int?, fallbackSeconds: Int, now: Date = Date()) -> String {
        let resetDate = resolveResetDate(resetAt: resetAt, fallbackSeconds: fallbackSeconds, now: now)

        if Calendar.current.isDate(resetDate, inSameDayAs: now) {
            return timeFormatter.string(from: resetDate)
        }

        return dateFormatter.string(from: resetDate)
    }

    static func resetRelativeLabel(resetAt: Int?, fallbackSeconds: Int, now: Date = Date()) -> String {
        let resetDate = resolveResetDate(resetAt: resetAt, fallbackSeconds: fallbackSeconds, now: now)
        let seconds = max(0, Int(resetDate.timeIntervalSince(now)))

        if seconds < 60 {
            return "in \(seconds)s"
        }

        if seconds < 3600 {
            return "in \(seconds / 60)m"
        }

        if seconds < 86_400 {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            if minutes == 0 {
                return "in \(hours)h"
            }

            return "in \(hours)h \(minutes)m"
        }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3600
        if hours == 0 {
            return "in \(days)d"
        }

        return "in \(days)d \(hours)h"
    }

    private static func resolveResetDate(resetAt: Int?, fallbackSeconds: Int, now: Date) -> Date {
        if let resetAt {
            return Date(timeIntervalSince1970: TimeInterval(resetAt))
        }

        return now.addingTimeInterval(TimeInterval(fallbackSeconds))
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}
