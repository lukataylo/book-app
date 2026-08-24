import Foundation
import SwiftData

/// Loads the bundled catalog of original Epigrapha summaries ("The Big Ideas
/// in …") — the Read tab's summary-first content.
///
/// `BookApp/Resources/SummaryPacks/<slug>.json` contains, per title: catalog
/// metadata, the summary text, curated passages seeded as highlights, and
/// any bundled comic re-styles. (Packs also carry `cards` / `actions`
/// blocks from the shelved Remember and Act features — unknown keys, so
/// the decoder ignores them.)
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
    private static let fullTextFolder = "FullTexts"
    // Bumping this key re-runs the per-pack pass over books that are
    // already seeded, which is the only way the existing-book branch ever
    // executes — `pending` filters loaded slugs out before anything else
    // runs. Bump it whenever a pack gains something that has to reach
    // existing installs: a designed cover, a quick take, a re-style.
    //
    // v4: the public-domain source text now ships alongside the summary.
    // The book it belongs to changes shape — the full text takes the
    // `.original` slot and the summary moves to `.compressed` — so every
    // already-seeded book has to be revisited. The content-by-title
    // guard prevents duplicates.
    nonisolated static let loadedSlugsKey = "SummaryPacks.loadedSlugs-v4"

    /// Clear the re-seed guard so the catalog comes back on next launch.
    ///
    /// Settings → Reset all content used to hardcode its own copy of this
    /// key. The two drifted (`-v2` against a loader on `-v4`), which meant
    /// a reset wiped the library and then blocked the re-seed — leaving an
    /// app that was empty forever and could only be recovered by deleting
    /// it. Owning the key here makes that class of bug impossible.
    /// `nonisolated` because store recovery runs before the main actor is
    /// available — it only touches UserDefaults, which is thread-safe.
    nonisolated static func resetSeedFlag() {
        UserDefaults.standard.removeObject(forKey: loadedSlugsKey)
    }

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

        // Runs before the `pending` early-return: a release that only
        // *withdraws* titles adds no pending packs, so anything after that
        // guard would never execute.
        pruneWithdrawn(bundled: files, context: modelContext)

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
                    #if DEBUG
                    print("[SummaryPacks] failed to decode \(file.lastPathComponent)")
                    #endif
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

    /// Remove catalog books whose pack no longer ships.
    ///
    /// The loader only ever inserted and updated, so withdrawing a title
    /// from the bundle left it sitting on every device that had already
    /// seeded it. That is how ~50 in-copyright summaries stayed on
    /// installed devices after they were pulled from the repo for legal
    /// reasons, still readable, just without new cover art.
    ///
    /// Only touches `isSummaryEdition` books, so anything the user
    /// imported themselves is never in scope.
    static func pruneWithdrawn(bundled files: [URL], context: ModelContext) {
        let shipping = Set(files.map { $0.deletingPathExtension().lastPathComponent })
        guard !shipping.isEmpty else { return }        // never prune on a bad read

        // Match on the slug the loader stamped into `artSlug`, falling back
        // to the title for rows seeded before that field existed.
        let titles = Set(shipping.map { slugToTitleKey($0) })
        let existing = (try? context.fetch(
            FetchDescriptor<Book>(predicate: #Predicate { $0.isSummaryEdition }))) ?? []

        var removed = 0
        for book in existing {
            let bySlug = !book.artSlug.isEmpty && shipping.contains(book.artSlug)
            let byTitle = titles.contains(titleKey(book.title))
            guard !bySlug, !byTitle else { continue }
            BookStore.shared.deleteBookFolder(for: book.id)
            context.delete(book)
            removed += 1
        }
        if removed > 0 {
            try? context.save()
            #if DEBUG
            print("[SummaryPacks] removed \(removed) withdrawn title(s)")
            #endif
        }
    }

    /// Slugs and titles have to be compared through the same normalisation,
    /// because a book seeded before `artSlug` existed has only its title.
    static func titleKey(_ title: String) -> String {
        title.lowercased()
            .replacingOccurrences(of: "the big ideas in ", with: "")
            .filter { $0.isLetter || $0.isNumber }
    }

    static func slugToTitleKey(_ slug: String) -> String {
        slug.replacingOccurrences(of: "-", with: "").filter { $0.isLetter || $0.isNumber }
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

    /// Average adult reading speed. Used for every variant's label so the
    /// time shown is derived from the words actually shipped, not a
    /// number typed into a JSON file.
    static let wordsPerMinute = 250

    static func minutes(forWords words: Int) -> Int {
        max(1, Int((Double(words) / Double(wordsPerMinute)).rounded()))
    }

    /// "5 min" / "1 h 12 min" — the same shape used on the book page.
    static func durationLabel(forWords words: Int) -> String {
        let mins = minutes(forWords: words)
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60, m = mins % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    /// The bundled public-domain source text for a pack, if one ships.
    /// Not every title has one — Gutenberg carries no Moral Letters, for
    /// instance — so a missing file is a normal outcome, and that book
    /// simply keeps the summary in the `.original` slot.
    static func fullText(for slug: String) -> String? {
        guard let url = Bundle.main.url(
            forResource: slug, withExtension: "txt", subdirectory: fullTextFolder
        ) ?? Bundle.main.resourceURL?
            .appendingPathComponent(fullTextFolder, isDirectory: true)
            .appendingPathComponent("\(slug).txt")
        else { return nil }
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              !text.isEmpty else { return nil }
        return text
    }

    /// Returns true when the pack's records were saved (or already exist).
    /// Internal (not private) so the idempotency contract is unit-testable.
    @discardableResult
    static func seed(pack: SummaryPack, context: ModelContext, existingBooks: [String: Book]? = nil) -> Bool {
        // Content-based guard on top of the UserDefaults flag: the store is
        // CloudKit-synced, so a second device must not insert its own copy
        // of a summary book that already synced down.
        let books = existingBooks ?? existingSummaryBooks(context: context)
        // Empty unless a designed cover ships for this pack — the rest fall
        // back to the generated Idea-Glyph cover.
        let artSlug = CoverArt.hasDesignedCover(slug: pack.slug) ? pack.slug : ""
        if let existing = books[pack.title] {
            // Upgrade path: backfill the designed-cover slug onto books
            // seeded before vector covers shipped.
            if existing.artSlug != artSlug {
                existing.artSlug = artSlug
                try? context.save()
            }
            // Upgrade path: packs gained a short "quick take" variant after
            // launch — attach it to books seeded before it existed.
            if let gist = pack.summaryShort,
               !(existing.variants ?? []).contains(where: { $0.label == quickTakeLabel }) {
                insertQuickTake(gist, attribution: pack.attribution, book: existing, context: context)
                try? context.save()
            }
            // Same upgrade path for the bundled comic re-styles: match on
            // label so a pack that gains a voice in a later release attaches
            // it without duplicating the ones already there.
            let labels = Set((existing.variants ?? []).map(\.label))
            for voice in pack.styledVariants ?? [] where !labels.contains(voice.label) {
                insertStyled(voice, attribution: pack.attribution, book: existing, context: context)
                try? context.save()
            }
            attachFullText(pack: pack, book: existing, context: context)
            return true
        }

        let book = Book(title: pack.title, author: pack.sourceAuthor, format: .unknown)
        book.isSummaryEdition = true
        book.artSlug = artSlug
        book.sourceAttribution = pack.attribution
        book.categoryTags = pack.categories
        book.detectedThemes = pack.themes

        // The attribution travels with the text itself, but as the closing
        // paragraph — leading with it made Listen mode narrate legal
        // boilerplate before the first idea.
        let summaryText = pack.summary + "\n\n" + pack.attribution
        let summaryWords = wordCount(summaryText)
        // What the shelf advertises is the summary — that is the tier the
        // catalog is built around. Derived from the words actually
        // shipped, so it can't drift from the text the way a hand-typed
        // `read_minutes` did.
        book.readMinutesEstimate = minutes(forWords: summaryWords)
        context.insert(book)

        // The source work takes the `.original` slot: the summary is a
        // compression of it, not the other way round. Length estimates
        // follow the original, because that is what the Transformation
        // Studio's slider compresses from.
        let source = fullText(for: pack.slug)
        let originalWords = source.map(wordCount) ?? summaryWords
        book.totalWordsEstimate = originalWords
        book.totalPagesEstimate = max(originalWords / wordsPerMinute, 1)

        if let source {
            let full = BookVariant(book: book, kind: .original)
            full.label = "Full text · \(durationLabel(forWords: originalWords))"
            full.writeText(source)
            context.insert(full)

            let summary = BookVariant(book: book, kind: .compressed, targetPages: max(summaryWords / wordsPerMinute, 1))
            summary.label = "The Big Ideas · \(durationLabel(forWords: summaryWords))"
            summary.writeText(summaryText)
            context.insert(summary)
        } else {
            // No source text ships for this title, so the summary keeps
            // the `.original` slot — `book.originalVariant` is never nil.
            let summary = BookVariant(book: book, kind: .original)
            summary.label = "The Big Ideas · \(durationLabel(forWords: summaryWords))"
            summary.writeText(summaryText)
            context.insert(summary)
        }

        // The ~3-minute "quick take" — the catalog's second length tier,
        // listed alongside the full summary in the book's variants.
        // Bundled comic re-styles ("as staged by Shakespeare"). Pre-generated
        // so the Transformation Studio's headline trick is visible on a fresh
        // install with no API key and no waiting.
        for voice in pack.styledVariants ?? [] {
            insertStyled(voice, attribution: pack.attribution, book: book, context: context)
        }

        if let gist = pack.summaryShort {
            insertQuickTake(gist, attribution: pack.attribution, book: book, context: context)
        }

        // Curated passages seed the highlights gallery, so a fresh install
        // has a populated Saved tab.
        let palette: [AnnotationColor] = [.yellow, .blue, .pink, .green, .purple]
        for (idx, entry) in pack.learnings.enumerated() {
            let annotation = Annotation(
                book: book,
                variantID: nil,
                quotedText: entry.text,
                note: entry.chapter,
                color: palette[idx % palette.count]
            )
            context.insert(annotation)
        }

        do {
            try context.save()
            return true
        } catch {
            // Roll the failed pack's pending inserts back so one bad pack
            // can't poison every subsequent pack's save in this run.
            context.rollback()
            #if DEBUG
            print("[SummaryPacks] save failed for \(pack.slug): \(error)")
            #endif
            return false
        }
    }

    /// Upgrade path for books seeded before the source text shipped.
    ///
    /// The summary used to hold the `.original` slot; now the work itself
    /// does, and the summary becomes the compressed tier beside it. Both
    /// halves are idempotent — a book that has already been converted has
    /// an `.original` whose label starts with "Full text", and re-running
    /// leaves it untouched.
    static func attachFullText(pack: SummaryPack, book: Book, context: ModelContext) {
        guard let source = fullText(for: pack.slug) else { return }
        let variants = book.variants ?? []
        guard !variants.contains(where: { $0.label.hasPrefix("Full text") }) else { return }

        let originalWords = wordCount(source)
        book.totalWordsEstimate = originalWords
        book.totalPagesEstimate = max(originalWords / wordsPerMinute, 1)

        // Demote the incumbent original — same row, so the user's
        // highlights and reading position in the summary survive.
        if let summary = variants.first(where: { $0.kind == .original }) {
            let summaryWords = wordCount(pack.summary + "\n\n" + pack.attribution)
            summary.kind = .compressed
            summary.targetPages = max(summaryWords / wordsPerMinute, 1)
            summary.label = "The Big Ideas · \(durationLabel(forWords: summaryWords))"
            book.readMinutesEstimate = minutes(forWords: summaryWords)
        }

        let full = BookVariant(book: book, kind: .original)
        full.label = "Full text · \(durationLabel(forWords: originalWords))"
        full.writeText(source)
        context.insert(full)
        try? context.save()
    }

    private static func insertQuickTake(_ gist: String, attribution: String, book: Book, context: ModelContext) {
        let variant = BookVariant(book: book, kind: .compressed, targetPages: 2)
        variant.label = quickTakeLabel
        variant.writeText(gist + "\n\n" + attribution)
        context.insert(variant)
    }

    private static func insertStyled(
        _ voice: SummaryPack.PackStyledVariant,
        attribution: String,
        book: Book,
        context: ModelContext
    ) {
        let variant = BookVariant(book: book, kind: .styled, styleReference: voice.style)
        variant.label = voice.label
        variant.writeText(voice.text + "\n\n" + attribution)
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
    let sourceAuthor: String
    let sourceYear: Int
    let categories: [String]
    let themes: [String]
    let attribution: String
    let summary: String
    /// ~3-minute "quick take" gist — the catalog's short length tier.
    /// Optional so a pack without one still decodes.
    let summaryShort: String?
    let learnings: [PackLearning]
    /// Pre-generated comic re-styles. Optional so a pack without one decodes.
    let styledVariants: [PackStyledVariant]?

    struct PackLearning: Decodable, Sendable {
        let text: String
        let chapter: String
    }

    /// One bundled re-style. `style` is the voice as the Transformation
    /// Studio would express it, so a user can regenerate or extend it.
    /// Voices are public-domain authors or genre registers only — naming a
    /// living author invites right-of-publicity claims (content-legal-review).
    struct PackStyledVariant: Decodable, Sendable {
        let label: String
        let style: String
        let text: String
    }
}
