import SwiftUI

struct PopoverRoot: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var preferences: Preferences
    var onSettingsChange: () -> Void

    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if preferences.showExtraUsageOptionalBanner && !showingSettings {
                extraUsageBanner
                Divider()
            }

            if showingSettings {
                settingsView
            } else {
                mainView
            }

            Divider()
            bottomBar
        }
        .frame(width: 320)
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.didCloseNotification)) { _ in
            showingSettings = false
        }
    }

    private var mainView: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusSection(coordinator: coordinator)

            if preferences.uptimeHistory != .off && !coordinator.uptime.isEmpty {
                UptimeSection(coordinator: coordinator, preferences: preferences)
            }

            Divider()
            UsageSection(coordinator: coordinator, preferences: preferences)

            if preferences.extraUsageDisplay.shouldShow(coordinator.quota.extraUsage) {
                Divider()
                ExtraUsageSection(coordinator: coordinator, preferences: preferences)
            }

            if preferences.usageHistoryMode != .off {
                Divider()
                UsageHistorySection(
                    coordinator: coordinator,
                    preferences: preferences,
                    history: coordinator.history
                )
            }
        }
        .padding(14)
    }

    private var settingsView: some View {
        ScrollView {
            SettingsSection(
                preferences: preferences,
                onChange: onSettingsChange
            )
            .padding(14)
        }
        .frame(minHeight: 400)
    }

    /// One-time heads-up shown to existing users after the extra-usage feature
    /// became opt-in. Dismissed (or "Open Settings") clears the flag for good.
    private var extraUsageBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
            VStack(alignment: .leading, spacing: 4) {
                Text("Extra-usage tracking is now optional.")
                    .font(.caption).fontWeight(.medium)
                Text("Fetching your pay-as-you-go spend uses your Claude sign-in — technically a legal gray area under Anthropic’s terms. We left it on since you were already using it, but you can turn it off in Settings.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") {
                    preferences.showExtraUsageOptionalBanner = false
                    showingSettings = true
                }
                .font(.caption)
                .buttonStyle(.link)
                .padding(.top, 1)
            }
            Spacer(minLength: 0)
            Button {
                preferences.showExtraUsageOptionalBanner = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
    }

    private var bottomBar: some View {
        HStack {
            Button(action: { showingSettings.toggle() }) {
                Image(systemName: showingSettings ? "chevron.left" : "gearshape")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help(showingSettings ? "Back" : "Settings")

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
