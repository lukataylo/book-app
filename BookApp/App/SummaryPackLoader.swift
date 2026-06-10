import Foundation
import SwiftData

/// Loads the bundled catalog of original BookApp summaries ("The Big Ideas
/// in …") — the Read tab's summary-first content.
///
/// `BookApp/Resources/SummaryPacks/<slug>.json` contains, per title: catalog
/// metadata, the legally-safe summary text, curated key learnings, a deck of
/// knowledge cards (Remember tab) and a 14-day action plan (Act tab).
///
/// Unlike `SeedBooksLoader` there is no EPUB to import: the summary IS the
/// content, stored as the book's `.original` variant so the reader, TTS,
/// speed-reading and transformation features all work on it unchanged.
///
/// Idempotency is per-slug (a UserDefaults string array), so packs added in
/// a later app update are picked up without re-seeding existing ones.
@MainActor
enum SummaryPackLoader {

    private static let resourceFolder = "SummaryPacks"
    private static let loadedSlugsKey = "SummaryPacks.loadedSlugs-v1"

    static func runIfNeeded(modelContext: ModelContext) async {
        guard let folderURL = bundledFolderURL() else { return }
        let files: [URL]
        do {
            files = try FileManager.default
                .contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            return
        }

        var loaded = Set(UserDefaults.standard.stringArray(forKey: loadedSlugsKey) ?? [])
        // slug == filename for every shipped pack, so the already-loaded
        // check runs before any decode work.
        let pending = files.filter { !loaded.contains($0.deletingPathExtension().lastPathComponent) }
        guard !pending.isEmpty else { return }

        // The catalog is ~80 packs (~2 MB of JSON) — decode off the main
        // actor; only the SwiftData inserts happen on it.
        let packs = await Task.detached(priority: .utility) { () -> [SummaryPack] in
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return pending.compactMap { file in
                guard let data = try? Data(contentsOf: file),
                      let pack = try? decoder.decode(SummaryPack.self, from: data) else {
                    print("[SummaryPacks] failed to decode \(file.lastPathComponent)")
                    return nil
                }
                return pack
            }
        }.value

        // One fetch for the duplicate guard instead of one per pack —
        // first launch seeds ~80 packs and O(n²) fetches would all land
        // on the main actor. The map needs no refresh inside the loop:
        // it only guards against books that pre-date this run, and pack
        // titles are unique (test-enforced), so packs can't collide with
        // each other.
        let existing = Self.existingSummaryBooks(context: modelContext)

        for pack in packs {
            guard !loaded.contains(pack.slug) else { continue }
            guard seed(pack: pack, context: modelContext, existingBooks: existing) else { continue }
            // Persist per pack, not after the loop — a crash mid-seed must
            // not re-seed (and duplicate) the packs that already saved.
            loaded.insert(pack.slug)
            UserDefaults.standard.set(Array(loaded).sorted(), forKey: loadedSlugsKey)
            // Keep first launch responsive while ~80 packs insert.
            await Task.yield()
        }
    }

    /// Summary-edition books already in the store, keyed by title.
    /// Captured-variable #Predicate translation is unreliable (see
    /// SeedBooksLoader), so this fetches the summary editions and matches
    /// in memory — the catalog is small by construction.
    static func existingSummaryBooks(context: ModelContext) -> [String: Book] {
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.isSummaryEdition })
        let existing = (try? context.fetch(descriptor)) ?? []
        return Dictionary(existing.map { ($0.title, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Label prefix identifying the bundled short-length variant.
    static let quickTakeLabel = "Quick take · 3 min"

    /// Returns true when the pack's records were saved (or already exist).
    /// Internal (not private) so the idempotency contract is unit-testable.
    @discardableResult
    static func seed(pack: SummaryPack, context: ModelContext, existingBooks: [String: Book]? = nil) -> Bool {
        // Content-based guard on top of the UserDefaults flag: the store is
        // CloudKit-synced, so a second device must not insert its own copy
        // of a summary book that already synced down.
        let books = existingBooks ?? existingSummaryBooks(context: context)
        if let existing = books[pack.title] {
            // Upgrade path: packs gained a short "quick take" variant after
            // launch — attach it to books seeded before it existed.
            if let gist = pack.summaryShort,
               !(existing.variants ?? []).contains(where: { $0.label == quickTakeLabel }) {
                insertQuickTake(gist, attribution: pack.attribution, book: existing, context: context)
                try? context.save()
            }
            return true
        }

        let book = Book(title: pack.title, author: pack.sourceAuthor, format: .unknown)
        book.isSummaryEdition = true
        book.sourceAttribution = pack.attribution
        book.readMinutesEstimate = pack.readMinutes
        book.categoryTags = pack.categories
        book.detectedThemes = pack.themes

        // The reader renders the attribution as the summary's first
        // paragraph so the legal framing travels with the text itself.
        let contentText = pack.attribution + "\n\n" + pack.summary
        let words = contentText.split(whereSeparator: { $0.isWhitespace }).count
        book.totalWordsEstimate = words
        book.totalPagesEstimate = max(words / 250, 1)
        context.insert(book)

        let variant = BookVariant(book: book, kind: .original, contentText: contentText)
        variant.label = "Summary"
        context.insert(variant)

        // The ~3-minute "quick take" — the catalog's second length tier,
        // listed alongside the full summary in the book's variants.
        if let gist = pack.summaryShort {
            insertQuickTake(gist, attribution: pack.attribution, book: book, context: context)
        }

        // Curated learnings — mirrored as Annotations so the highlights
        // gallery is populated, matching SeedBooksLoader's behaviour.
        let palette: [AnnotationColor] = [.yellow, .blue, .pink, .green, .purple]
        for (idx, entry) in pack.learnings.enumerated() {
            let learning = KeyLearning(book: book, text: entry.text, chapterRef: entry.chapter)
            context.insert(learning)
            let annotation = Annotation(
                book: book,
                variantID: nil,
                quotedText: entry.text,
                note: entry.chapter,
                color: palette[idx % palette.count]
            )
            context.insert(annotation)
        }

        for (idx, card) in pack.cards.enumerated() {
            context.insert(KnowledgeCard(
                book: book,
                title: card.title,
                body: card.body,
                category: card.category,
                order: idx,
                source: "seed"
            ))
        }

        for (idx, action) in pack.actions.enumerated() {
            context.insert(ActionItem(
                book: book,
                title: action.title,
                detail: action.detail,
                kind: ActionKind(rawValue: action.kind) ?? .task,
                dayOffset: action.day,
                durationMinutes: action.durationMinutes,
                order: idx
            ))
        }

        do {
            try context.save()
            return true
        } catch {
            // Roll the failed pack's pending inserts back so one bad pack
            // can't poison every subsequent pack's save in this run.
            context.rollback()
            print("[SummaryPacks] save failed for \(pack.slug): \(error)")
            return false
        }
    }

    private static func insertQuickTake(_ gist: String, attribution: String, book: Book, context: ModelContext) {
        let variant = BookVariant(
            book: book,
            kind: .compressed,
            contentText: attribution + "\n\n" + gist,
            targetPages: 2
        )
        variant.label = quickTakeLabel
        context.insert(variant)
    }

    private static func bundledFolderURL() -> URL? {
        if let url = Bundle.main.url(forResource: resourceFolder, withExtension: nil) {
            return url
        }
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let candidate = URL(fileURLWithPath: resourcePath)
            .appendingPathComponent(resourceFolder, isDirectory: true)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}

// MARK: - <slug>.json schema (decoded with .convertFromSnakeCase)

struct SummaryPack: Decodable, Sendable {
    let slug: String
    let title: String
    let sourceTitle: String
    let sourceAuthor: String
    let sourceYear: Int
    let categories: [String]
    let themes: [String]
    let readMinutes: Int
    let attribution: String
    let summary: String
    /// ~3-minute "quick take" gist — the catalog's short length tier.
    /// Optional so a pack without one still decodes.
    let summaryShort: String?
    let learnings: [PackLearning]
    let cards: [PackCard]
    let actions: [PackAction]

    struct PackLearning: Decodable, Sendable {
        let text: String
        let chapter: String
    }

    struct PackCard: Decodable, Sendable {
        let title: String
        let body: String
        let category: String
    }

    struct PackAction: Decodable, Sendable {
        let title: String
        let detail: String
        let kind: String
        let day: Int
        let durationMinutes: Int
    }
}
