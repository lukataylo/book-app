import Foundation
import SwiftData

/// Singleton accessor for the three @Model "settings" rows
/// (`ReaderSettings`, `TTSSettings`, `SpeedReaderSettings`). Each is a
/// process-wide singleton conceptually, but several call sites used to
/// fetch them inline via `FetchDescriptor` on every appearance — that
/// hits SwiftData's I/O path and blocks the main thread, especially while
/// CloudKit is mid-sync.
///
/// `SettingsStore` resolves them once per `ModelContext` and hands the
/// cached instances back. It also takes care of inserting a fresh row
/// when the user has none (first launch / iCloud-fresh device).
///
/// The store is `@MainActor` because SwiftData's `ModelContext` is itself
/// main-actor bound; callers should always be on the main actor when
/// reading.
@MainActor
final class SettingsStore {
    static let shared = SettingsStore()

    private var cachedReader: ReaderSettings?
    private var cachedTTS: TTSSettings?
    private var cachedSpeed: SpeedReaderSettings?

    private init() {}

    /// Reset cached references — used when the underlying `ModelContainer`
    /// is rebuilt (test fixtures, account switches). Production code
    /// shouldn't need to call this.
    func reset() {
        cachedReader = nil
        cachedTTS = nil
        cachedSpeed = nil
    }

    func reader(in context: ModelContext) -> ReaderSettings {
        if let cached = cachedReader, cached.modelContext === context {
            return cached
        }
        let resolved = Self.resolveOrCreate(in: context, factory: { ReaderSettings() })
        cachedReader = resolved
        return resolved
    }

    func tts(in context: ModelContext) -> TTSSettings {
        if let cached = cachedTTS, cached.modelContext === context {
            return cached
        }
        let resolved = Self.resolveOrCreate(in: context, factory: { TTSSettings() })
        cachedTTS = resolved
        return resolved
    }

    func speed(in context: ModelContext) -> SpeedReaderSettings {
        if let cached = cachedSpeed, cached.modelContext === context {
            return cached
        }
        let resolved = Self.resolveOrCreate(in: context, factory: { SpeedReaderSettings() })
        cachedSpeed = resolved
        return resolved
    }

    /// Generic helper that fetches the first existing row of a settings
    /// model, or inserts a fresh one. The save is queued onto the next
    /// runloop tick so the caller doesn't block the current frame on
    /// SwiftData / CloudKit.
    private static func resolveOrCreate<T: PersistentModel>(
        in context: ModelContext,
        factory: () -> T
    ) -> T {
        let descriptor = FetchDescriptor<T>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = factory()
        context.insert(created)
        // Defer the save so first-open of a settings sheet doesn't pay
        // the disk + CloudKit handshake cost up front.
        Task { @MainActor in
            try? context.save()
        }
        return created
    }
}
