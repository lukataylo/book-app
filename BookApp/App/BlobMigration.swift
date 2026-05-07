import Foundation
import SwiftData

/// One-time migration that moves multi-megabyte blobs out of the
/// SwiftData rows and onto disk:
///
///   - `Book.coverData` → `<bookFolder>/cover.jpg`,
///     leaves `coverFilename` populated and `coverData` set to nil.
///   - `BookVariant.contentText` → `<bookFolder>/variant-<id>.txt`,
///     leaves `contentFilename` populated and `contentText` empty.
///
/// CloudKit's per-record storage is strict (~1 MB per field); a single
/// 400-page book's text plus a high-res JPEG cover are enough to drag
/// every save into the slow path and occasionally lose the field
/// entirely. New imports already write to disk; this migration handles
/// the upgrade path for users who installed an earlier build.
///
/// Idempotent — UserDefaults flag means it only ever runs once per
/// device per blob class. It also re-runs to mop up any rows the
/// previous attempt couldn't write (disk full, permissions, etc.).
@MainActor
enum BlobMigration {

    private static let textDoneKey  = "BlobMigration.text-v1"
    private static let coverDoneKey = "BlobMigration.cover-v1"

    static func runIfNeeded(modelContext: ModelContext) {
        migrateText(modelContext: modelContext)
        migrateCovers(modelContext: modelContext)
    }

    private static func migrateText(modelContext: ModelContext) {
        if UserDefaults.standard.bool(forKey: textDoneKey) { return }

        let descriptor = FetchDescriptor<BookVariant>()
        guard let variants = try? modelContext.fetch(descriptor) else { return }

        var migrated = 0
        var pending = 0
        for variant in variants {
            // Already migrated rows have an empty contentText.
            guard !variant.contentText.isEmpty,
                  let bookID = variant.book?.id else { continue }
            let url = BookStore.shared.variantTextURL(bookID: bookID, variantID: variant.id)
            // If the file is already there (e.g. from a partial run),
            // just clear the in-row copy so CloudKit stops syncing it.
            if FileManager.default.fileExists(atPath: url.path) {
                variant.contentFilename = url.lastPathComponent
                variant.contentText = ""
                migrated += 1
                continue
            }
            if BookStore.shared.writeVariantText(variant.contentText,
                                                 bookID: bookID,
                                                 variantID: variant.id) {
                variant.contentFilename = url.lastPathComponent
                variant.contentText = ""
                migrated += 1
            } else {
                pending += 1
            }
        }

        if migrated > 0 {
            try? modelContext.save()
        }
        // Only flip the done flag when nothing is left over — otherwise
        // the next launch will retry the rows that failed to write
        // (transient disk-full / permission glitch).
        if pending == 0 {
            UserDefaults.standard.set(true, forKey: textDoneKey)
        }
    }

    private static func migrateCovers(modelContext: ModelContext) {
        if UserDefaults.standard.bool(forKey: coverDoneKey) { return }

        let descriptor = FetchDescriptor<Book>()
        guard let books = try? modelContext.fetch(descriptor) else { return }

        var migrated = 0
        var pending = 0
        for book in books {
            guard let data = book.coverData, !data.isEmpty else { continue }
            let url = BookStore.shared.coverURL(bookID: book.id)
            if FileManager.default.fileExists(atPath: url.path) {
                book.coverFilename = url.lastPathComponent
                book.coverData = nil
                migrated += 1
                continue
            }
            if BookStore.shared.writeCover(data, bookID: book.id) {
                book.coverFilename = url.lastPathComponent
                book.coverData = nil
                migrated += 1
            } else {
                pending += 1
            }
        }

        if migrated > 0 {
            try? modelContext.save()
        }
        if pending == 0 {
            UserDefaults.standard.set(true, forKey: coverDoneKey)
        }
    }
}
