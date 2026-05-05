#if DEBUG
import Foundation
import SwiftData

/// Debug-only first-launch seeder. Looks for EPUB / PDF / MOBI files in
/// `Documents/_seed/` and imports them through the normal pipeline. Used by
/// the simulator preview workflow — drop files into the sandbox via
/// `xcrun simctl get_app_container ... data` and the next launch picks
/// them up. Runs once per data-container; controlled by a UserDefaults flag
/// so re-launching the app doesn't double-import.
@MainActor
enum DevSeed {
    private static let folderName = "_seed"
    private static let doneKey    = "DevSeed.completed-v1"

    static func runIfNeeded(modelContext: ModelContext) async {
        if UserDefaults.standard.bool(forKey: doneKey) { return }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documents = docs.first else { return }
        let seedURL = documents.appendingPathComponent(folderName, isDirectory: true)

        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: seedURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            // No seed directory — nothing to do, mark done so we stop checking.
            UserDefaults.standard.set(true, forKey: doneKey)
            return
        }
        guard !entries.isEmpty else {
            UserDefaults.standard.set(true, forKey: doneKey)
            return
        }

        let supported: Set<String> = ["epub", "pdf", "mobi", "azw3"]
        let candidates = entries
            .filter { supported.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let service = ImportService(modelContext: modelContext)
        for url in candidates {
            do {
                _ = try await service.importBook(from: url)
                print("[DevSeed] imported \(url.lastPathComponent)")
            } catch {
                print("[DevSeed] failed \(url.lastPathComponent): \(error)")
            }
        }

        UserDefaults.standard.set(true, forKey: doneKey)
        try? FileManager.default.removeItem(at: seedURL)
    }
}
#endif
