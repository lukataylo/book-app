import Foundation
import SwiftData

/// One-time migration that assigns `Book.artSlug` to the three bundled seed
/// classics for users who installed before vector covers shipped. The summary
/// packs backfill themselves on the next launch (the `SummaryPacks.loadedSlugs`
/// key was bumped, which re-runs the per-pack pass), but `SeedBooksLoader` is
/// gated by a one-shot completion flag and never re-enters, so the seed books
/// need this dedicated, idempotent pass. Guarded by its own UserDefaults flag.
enum CoverArtBackfill {
    private static let doneKey = "CoverArt.seedBackfill-v1"

    /// Title → cover slug for the seed classics. Titles match the curated
    /// metadata in `SeedBooksLoader`; the slugs name `Covers.xcassets` assets.
    private static let seedSlugsByTitle: [String: String] = [
        "The Republic": "republic-plato",
        "The Prince": "prince-machiavelli",
        "Beyond Good and Evil": "beyond-good-evil-nietzsche"
    ]

    static func runIfNeeded(modelContext: ModelContext) {
        if UserDefaults.standard.bool(forKey: doneKey) { return }

        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { !$0.isSummaryEdition && $0.artSlug.isEmpty }
        )
        guard let books = try? modelContext.fetch(descriptor) else { return }

        var changed = false
        for book in books {
            if let slug = seedSlugsByTitle[book.title] {
                book.artSlug = slug
                changed = true
            }
        }
        if changed { try? modelContext.save() }

        UserDefaults.standard.set(true, forKey: doneKey)
    }
}
