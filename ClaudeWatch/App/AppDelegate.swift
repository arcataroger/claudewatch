import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hostingView: NSHostingView<MenuBarLabel>!

    let coordinator = AppCoordinator()
    let preferences = Preferences.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Migrations first: the existing-user check reads usage-history.json before
        // the coordinator's first sync would write to it.
        runMigrationsIfNeeded()
        setupStatusItem()
        setupPopover()
        coordinator.start()
        registerHotkey()
        // Keep the statusline hook's view of the extra-usage setting in sync.
        preferences.writeStatuslineConfig()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stop()
        GlobalHotkey.shared.unregister()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let label = MenuBarLabel(coordinator: coordinator, preferences: preferences)
        let host = NSHostingView(rootView: label)
        host.translatesAutoresizingMaskIntoConstraints = false
        self.hostingView = host

        if let button = statusItem.button {
            button.addSubview(host)
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                host.topAnchor.constraint(equalTo: button.topAnchor),
                host.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            ])
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 10)
        popover.contentViewController = NSHostingController(
            rootView: PopoverRoot(
                coordinator: coordinator,
                preferences: preferences,
                onSettingsChange: { [weak self] in
                    self?.coordinator.reschedule()
                    self?.registerHotkey()
                }
            )
        )
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Migrations

    /// Version-gated one-time upgrade steps. Compares the persisted
    /// `lastRanAppVersion` with the current bundle version, runs any needed
    /// migrations, then stamps the version forward. Must run before the coordinator
    /// starts, since the existing-user check reads usage-history.json, which the
    /// coordinator writes to on its first sync this session.
    private func runMigrationsIfNeeded() {
        let current = Self.appVersion
        let previous = preferences.lastRanAppVersion
        guard previous != current else { return }

        // Extra-usage opt-in migration. `previous` is empty only on the first launch
        // that records a version — either a brand-new install or an upgrade from an
        // older, pre-tracking build. Disambiguate via the app's own prior output: an
        // existing user (has recorded history) keeps the always-on behavior they had,
        // with a one-time heads-up; a fresh install stays at the default (off).
        // Future migrations gate on `previous` and never need this heuristic.
        if previous.isEmpty && UsageHistoryStore.hasPriorHistory {
            preferences.extraUsageFetchEnabled = true
            preferences.showExtraUsageOptionalBanner = true
        }

        preferences.lastRanAppVersion = current
        preferences.writeStatuslineConfig()
    }

    /// Current app version (`CFBundleShortVersionString`, falling back to build),
    /// never empty so the migration ledger always advances on first run.
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleShortVersionString"] as? String)
            ?? (info?["CFBundleVersion"] as? String)
            ?? "0"
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        GlobalHotkey.shared.register(
            keyCode: UInt32(preferences.hotkeyKeyCode),
            modifiers: UInt32(preferences.hotkeyModifiers)
        ) { [weak self] in
            self?.togglePopover(nil)
        }
    }
}
