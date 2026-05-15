import Foundation
import MetricKit
#if canImport(UIKit)
import UIKit
#endif

/// Subscribes to `MXMetricManager` for crash + hang diagnostics and writes
/// each payload to a JSON file under `Library/Caches/diagnostics/`. The
/// file is opaque (Apple's payload is JSON already) but the user can
/// export it from Settings → Diagnostics so they can attach it to a bug
/// report without us shipping a third-party crash SDK.
///
/// MetricKit delivers payloads roughly once a day as a batch — never in
/// real time. The `receiveReports` array is a snapshot of the current
/// 24h window. We don't filter; the file is local-only and the user
/// controls export.
@MainActor
final class MetricsLog: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricsLog()

    static let folderName = "diagnostics"

    /// Begin receiving MetricKit payloads. Safe to call multiple times —
    /// `MXMetricManager.add(_:)` deduplicates subscribers by identity.
    func start() {
        MXMetricManager.shared.add(self)
    }

    /// Stop receiving payloads. Mainly useful for tests; production code
    /// keeps the subscription alive for the app's lifetime.
    func stop() {
        MXMetricManager.shared.remove(self)
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        let blobs = payloads.map { $0.jsonRepresentation() }
        Task { @MainActor in
            self.write(payloads: blobs, prefix: "metrics")
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let blobs = payloads.map { $0.jsonRepresentation() }
        Task { @MainActor in
            self.write(payloads: blobs, prefix: "diagnostics")
        }
    }

    /// Files written so far, newest first. The Settings → Diagnostics
    /// surface uses this to populate an export list.
    static func storedFiles() -> [URL] {
        guard let folder = folderURL() else { return [] }
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.sorted { lhs, rhs in
            let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lDate > rDate
        }
    }

    /// Wipe accumulated diagnostics. Surfaced in Settings so the user
    /// can clear the queue after exporting.
    static func clearAll() {
        guard let folder = folderURL() else { return }
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for url in urls { try? fm.removeItem(at: url) }
    }

    // MARK: - Private

    private func write(payloads: [Data], prefix: String) {
        guard !payloads.isEmpty, let folder = Self.folderURL() else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        for (idx, payload) in payloads.enumerated() {
            let suffix = payloads.count > 1 ? "-\(idx)" : ""
            let url = folder.appendingPathComponent("\(prefix)-\(stamp)\(suffix).json")
            try? payload.write(to: url, options: .atomic)
        }
    }

    private static func folderURL() -> URL? {
        let fm = FileManager.default
        guard let caches = try? fm.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return caches.appendingPathComponent(folderName, isDirectory: true)
    }
}
