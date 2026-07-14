import SwiftUI
import ServiceManagement
import Combine

@MainActor
final class LaunchAtLoginModel: ObservableObject {
    @Published var enabled = SMAppService.mainApp.status == .enabled

    func setEnabled(_ value: Bool) {
        do {
            if value {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            enabled = SMAppService.mainApp.status == .enabled
        } catch {
            enabled = SMAppService.mainApp.status == .enabled
            print("Launch at login failed:", error)
        }
    }

    func refresh() {
        enabled = SMAppService.mainApp.status == .enabled
    }
}

private struct UsageWindowRow: View {
    let label: String
    let leftPercent: Int
    let resetRelativeLabel: String
    let resetAbsoluteLabel: String

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.semibold)
                .frame(width: 64, alignment: .leading)

            Spacer()

            Text("\(leftPercent)%")
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(resetRelativeLabel)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .font(.caption)
                Text("\(resetAbsoluteLabel)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .font(.caption)
            }
        }
    }
}

@main
struct CodexBarApp: App {
    @StateObject private var usage = CodexUsageModel()
    @StateObject private var launchAtLogin = LaunchAtLoginModel()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                    Text("Weekly limit remaining")
                        .font(.headline)
                }

                Divider()

                UsageWindowRow(
                    label: usage.weeklyLabel,
                    leftPercent: usage.weeklyLeft,
                    resetRelativeLabel: usage.weeklyResetRelative,
                    resetAbsoluteLabel: usage.weeklyResetAbsolute
                )

                HStack {
                    Text("Updated")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if usage.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(usage.updatedAt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    
                }

                Divider()

                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin.enabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))

                HStack {
                    Button(usage.isRefreshing ? "Updating..." : "Refresh") {
                        Task { await usage.refresh() }
                    }
                    .disabled(usage.isRefreshing)

                    Spacer()
                    
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                }
                
            }
            .padding()
            .frame(width: 250)
            .onAppear {
                launchAtLogin.refresh()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                Text(usage.title)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }
}
