import Combine
import Foundation

@MainActor
final class CodexUsageModel: ObservableObject {
    @Published var title = "…"
    @Published var weeklyLabel = "Weekly"
    @Published var weeklyLeft = 0
    @Published var weeklyResetRelative = "unknown"
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
            weeklyLabel = presentation.weeklyWindow.label
            weeklyLeft = presentation.weeklyWindow.leftPercent
            weeklyResetRelative = presentation.weeklyWindow.resetRelativeLabel
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
