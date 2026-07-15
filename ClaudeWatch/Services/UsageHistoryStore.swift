import Foundation

/// Persists the 5-hour usage event log to JSON in the app's container-scoped
/// Application Support directory. Writable under sandbox without any file
/// exception in entitlements.
///
/// Events are retained indefinitely — the heatmap displays a bounded window
/// (~26 weeks), but the stat grid's "All" duration covers every event ever
/// recorded. Long-term storage cost is low: a year of real usage is only a
/// few hundred KB of JSON.
@MainActor
final class UsageHistoryStore: ObservableObject {
    @Published private(set) var events: [UsageHistoryEvent] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Location of the persisted history file, resolved without side effects
    /// (`init` uses the same path but also creates the directory).
    static var fileURL: URL {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: false))
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("ClaudeWatch", isDirectory: true)
            .appendingPathComponent("usage-history.json")
    }

    /// True if a history file with at least one recorded event already exists —
    /// i.e. a prior version of the app has run. Used once to detect existing users
    /// during migration; prefer `Preferences.lastRanAppVersion` for future gating.
    static var hasPriorHistory: Bool {
        guard let data = try? Data(contentsOf: fileURL) else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([UsageHistoryEvent].self, from: data))?.isEmpty == false
    }

    init() {
        let url = Self.fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        self.fileURL = url

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.withoutEscapingSlashes]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        load()
    }

    func append(_ event: UsageHistoryEvent) {
        events.append(event)
        save()
    }

    /// Events occurring on or after `cutoff`, useful for filtering to a
    /// user-selected duration.
    func events(since cutoff: Date) -> [UsageHistoryEvent] {
        events.filter { $0.at >= cutoff }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([UsageHistoryEvent].self, from: data)
        else { return }
        events = decoded
    }

    private func save() {
        guard let data = try? encoder.encode(events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
