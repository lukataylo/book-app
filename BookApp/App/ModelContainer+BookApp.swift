import Foundation
import SwiftData

extension ModelContainer {
    /// Production model container with CloudKit private-database sync enabled.
    /// All `@Model` types are registered here in one place so callers don't
    /// have to keep this list in sync.
    static func bookApp() throws -> ModelContainer {
        let schema = Schema([
            Book.self,
            BookVariant.self,
            KeyLearning.self,
            Annotation.self,
            ReadingProgress.self,
            ReaderSettings.self,
            TTSSettings.self,
            SpeedReaderSettings.self
        ])
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

    /// In-memory container for previews + tests + simulator fallback.
    /// Returns `nil` on the rare schema-load failure so callers can handle it
    /// without crashing the app or test runner.
    static func bookAppPreview() throws -> ModelContainer {
        let schema = Schema([
            Book.self, BookVariant.self, KeyLearning.self,
            Annotation.self, ReadingProgress.self,
            ReaderSettings.self, TTSSettings.self, SpeedReaderSettings.self
        ])
        // CloudKit explicitly off for in-memory: avoids the unique-constraint
        // validation path that otherwise rejects this configuration.
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
