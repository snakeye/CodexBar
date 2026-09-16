import Combine
import Foundation

@MainActor
final class CodexUsageModel: ObservableObject {
    @Published var title = "…"
    @Published var shortLabel = "5h"
    @Published var weeklyLabel = "Weekly"
    @Published var shortLeft = 0
    @Published var weeklyLeft = 0
    @Published var shortResetRelative = "unknown"
    @Published var weeklyResetRelative = "unknown"
    @Published var shortResetAbsolute = "unknown"
    @Published var weeklyResetAbsolute = "unknown"
    @Published var updatedAt = "never"
    @Published private(set) var isRefreshing = false

    private let service = CodexUsageService()
    private var refreshTask: Task<Void, Never>?

    init() {
        startAutoRefresh()
    }

    deinit {
        refreshTask?.cancel()
    }

    func startAutoRefresh() {
        guard refreshTask == nil else { return }

        refreshTask = Task { [weak self] in
            await self?.refresh()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let now = Date()
            let usage = try await service.fetchUsage()
            let presentation = CodexUsagePresentation.make(from: usage, now: now)

            title = presentation.title
            shortLabel = presentation.shortWindow.label
            weeklyLabel = presentation.weeklyWindow.label
            shortLeft = presentation.shortWindow.leftPercent
            weeklyLeft = presentation.weeklyWindow.leftPercent
            shortResetRelative = presentation.shortWindow.resetRelativeLabel
            weeklyResetRelative = presentation.weeklyWindow.resetRelativeLabel
            shortResetAbsolute = presentation.shortWindow.resetAbsoluteLabel
            weeklyResetAbsolute = presentation.weeklyWindow.resetAbsoluteLabel
            updatedAt = Self.timeFormatter.string(from: now)
        } catch let error as CodexUsageError {
            title = CodexUsagePresentation.makeErrorTitle(for: error)

            print("CodexBar refresh failed:", error.logMessage)
        } catch {
            title = "Codex err"
            print("CodexBar refresh failed:", error)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
