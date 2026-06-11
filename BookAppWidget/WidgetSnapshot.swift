import Foundation

/// Shared payload written by the main app whenever reading progress
/// changes and read by the widget extension. Lives in the App Group
/// container so both processes can see the same bytes; we use a JSON file
/// (atomic write) rather than UserDefaults because it gives us a coherent
/// snapshot — UserDefaults has a per-key cache that can drift between
/// processes.
struct WidgetSnapshot: Codable, Sendable {
    var bookID: String
    var title: String
    var author: String
    var percent: Double
    /// File name (within the App Group container's `widget-cover/` folder)
    /// of the most-recently-saved cover, or empty when the book has no
    /// cover. The widget reads bytes via `UIImage(contentsOfFile:)`.
    var coverFilename: String
    var updatedAt: Date

    static let appGroupID = "group.com.lukataylor.bookapp"
    static let snapshotFilename = "continue-reading.json"
    static let coverFolder = "widget-cover"

    static func containerURL() -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )
    }

    static func snapshotURL() -> URL? {
        containerURL()?.appendingPathComponent(snapshotFilename)
    }

    static func coverURL(filename: String) -> URL? {
        guard !filename.isEmpty,
              let folder = containerURL()?.appendingPathComponent(coverFolder, isDirectory: true)
        else { return nil }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(filename)
    }

    static func read() -> WidgetSnapshot? {
        guard let url = snapshotURL(),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func write() {
        guard let url = WidgetSnapshot.snapshotURL() else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(self) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

/// Shared payload for the "Today's Memory" widget. Written by the main app
/// (see `MemorySnapshotWriter`) and read by the widget extension. Lives in
/// the same App Group container as `WidgetSnapshot`, in its own JSON file so
/// the two widgets never contend for one snapshot.
struct MemorySnapshot: Codable, Sendable {
    /// Number of cards due today, after the daily-cap rule (spec §3a).
    var dueCount: Int
    /// Prompt text of the first due card, or empty when nothing is due.
    var topCardText: String
    var updatedAt: Date

    static let snapshotFilename = "todays-memory.json"

    static func snapshotURL() -> URL? {
        WidgetSnapshot.containerURL()?.appendingPathComponent(snapshotFilename)
    }

    static func read() -> MemorySnapshot? {
        guard let url = snapshotURL(),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MemorySnapshot.self, from: data)
    }

    func write() {
        guard let url = MemorySnapshot.snapshotURL() else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(self) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
