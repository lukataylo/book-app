import Foundation
import SwiftData

/// One-time migration that mirrors every existing `KeyLearning` row into
/// an `Annotation` so the new Bookmarks gallery (v11) is populated for
/// users who installed the app before the seed loader started writing
/// annotations directly. Idempotent — guarded by its own UserDefaults
/// flag so it runs at most once per device.
@MainActor
enum AnnotationBackfill {

    private static let doneKey = "Annotations.backfill-v1"

    static func runIfNeeded(modelContext: ModelContext) {
        if UserDefaults.standard.bool(forKey: doneKey) { return }

        let descriptor = FetchDescriptor<KeyLearning>()
        let learnings = (try? modelContext.fetch(descriptor)) ?? []

        // Build a set of `(bookID, quotedText)` already present as
        // Annotations so we don't double-insert when a user has both
        // pre-seeded learnings and post-v11 user-created highlights.
        let existingDescriptor = FetchDescriptor<Annotation>()
        let existing = (try? modelContext.fetch(existingDescriptor)) ?? []
        var seen = Set<String>()
        for ann in existing {
            guard let bookID = ann.book?.id else { continue }
            seen.insert(key(bookID: bookID, text: ann.quotedText))
        }

        let palette: [AnnotationColor] = [.yellow, .blue, .pink, .green, .purple]
        var inserted = 0
        for (idx, learning) in learnings.enumerated() {
            guard let book = learning.book else { continue }
            let k = key(bookID: book.id, text: learning.text)
            if seen.contains(k) { continue }
            let annotation = Annotation(
                book: book,
                variantID: nil,
                quotedText: learning.text,
                note: learning.chapterRef,
                color: palette[idx % palette.count]
            )
            modelContext.insert(annotation)
            seen.insert(k)
            inserted += 1
        }

        if inserted > 0 {
            try? modelContext.save()
        }
        UserDefaults.standard.set(true, forKey: doneKey)
    }

    private static func key(bookID: UUID, text: String) -> String {
        "\(bookID.uuidString)::\(text)"
    }
}
