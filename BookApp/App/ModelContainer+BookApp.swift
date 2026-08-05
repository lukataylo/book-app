import Foundation
import SwiftData

extension ModelContainer {
    /// The one list of `@Model` types, shared by the production and
    /// preview containers so they can't drift apart.
    static let bookAppSchema = Schema([
            Book.self,
            BookVariant.self,
            KeyLearning.self,
            Annotation.self,
            ReadingProgress.self,
            Bookmark.self,
            ReaderSettings.self,
            TTSSettings.self,
            SpeedReaderSettings.self
    ])

    /// Filename of the on-disk store, used both to open it and to remove
    /// it when it can no longer be opened.
    private static let storeName = "BookAppStore"

    /// Production model container with CloudKit private-database sync enabled.
    static func bookApp() throws -> ModelContainer {
        let schema = bookAppSchema
        // CloudKit + simulator without code signing → instant SIGTRAP in
        // `[PFCloudKitContainerProvider containerWithIdentifier:options:]`
        // because the entitlement isn't applied. Disk-only on simulator,
        // CloudKit-private on real devices.
        #if targetEnvironment(simulator)
        let config = ModelConfiguration(
            "BookAppStore",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        #else
        let config = ModelConfiguration(
            "BookAppStore",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.lukataylor.bookapp")
        )
        #endif
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Opens the real store, and if it cannot be opened, removes it and
    /// opens a fresh one.
    ///
    /// The alternative — falling back to an in-memory container — is worse
    /// than it looks: the app launches, the catalog re-seeds into memory,
    /// everything appears to work, and every book the user imported is
    /// gone again on the next launch with no error shown. A store that
    /// can't be opened is unrecoverable either way; resetting it at least
    /// leaves the app in a working state, and the bundled catalog re-seeds
    /// itself on the next launch.
    ///
    /// `didReset` tells the caller whether this happened, so the UI can say
    /// so rather than silently presenting an empty library.
    static func bookAppRecovering() -> (container: ModelContainer?, didReset: Bool) {
        do {
            return (try bookApp(), false)
        } catch {
            removeStoreFiles()
            // Re-seeding is gated on UserDefaults flags that outlive the
            // store, so they have to be cleared too or the fresh store
            // stays empty forever.
            for key in ["SummaryPacks.loadedSlugs-v3", "SeedBooks.completed-v1",
                        "Annotations.backfill-v1", "CoverArt.seedBackfill-v1",
                        "BlobMigration.completed-v1"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            return ((try? bookApp()), true)
        }
    }

    private static func removeStoreFiles() {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ) else { return }
        // SQLite keeps its write-ahead log and shared-memory file beside
        // the store; leaving them behind corrupts the replacement.
        for suffix in ["store", "store-shm", "store-wal"] {
            try? FileManager.default.removeItem(at: dir.appending(path: "\(storeName).\(suffix)"))
        }
    }

    /// In-memory container for previews + tests + simulator fallback.
    /// Returns `nil` on the rare schema-load failure so callers can handle it
    /// without crashing the app or test runner.
    static func bookAppPreview() throws -> ModelContainer {
        let schema = bookAppSchema
        // CloudKit explicitly off for in-memory: avoids the unique-constraint
        // validation path that otherwise rejects this configuration.
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
