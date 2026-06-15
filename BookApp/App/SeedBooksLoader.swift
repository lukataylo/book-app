import Foundation
import SwiftData

/// First-launch seeder for the bundled demo library.
///
/// `BookApp/Resources/SeedBooks/<slug>/` contains, for each demo book:
///   - `original.epub`           — the imported source
///   - `cover.jpg` (optional)    — fallback cover if the parser misses one
///   - `meta.json`               — book + variant metadata
///   - `<variant>.txt` (× N)     — pre-baked transformation outputs
///
/// On first launch we copy the EPUB into the iCloud Drive container, run
/// the existing `ImportService` (so the same parsing pipeline produces the
/// `Book` and the `.original` `BookVariant`), then fan out additional
/// `BookVariant` rows from the `.txt` files. Subsequent launches skip the
/// whole thing via a UserDefaults flag.
@MainActor
enum SeedBooksLoader {

    private static let resourceFolder = "SeedBooks"
    private static let doneKey        = "SeedBooks.completed-v1"
    private static let inProgressKey  = "SeedBooks.inProgress-v1"

    static func runIfNeeded(modelContext: ModelContext) async {
        if UserDefaults.standard.bool(forKey: doneKey) { return }

        // Detect crashed-mid-seed: a previous launch flipped the flag
        // but never made it to the end. Roll the partial state back so
        // we don't end up with duplicate books or half-imported variants
        // when the loader runs again.
        if UserDefaults.standard.bool(forKey: inProgressKey) {
            rollbackPartialSeed(modelContext: modelContext)
            UserDefaults.standard.removeObject(forKey: inProgressKey)
        }
        UserDefaults.standard.set(true, forKey: inProgressKey)

        guard let resourceURL = bundledFolderURL() else {
            // Bundle missing — likely Debug build with no seed assets. Mark
            // done so we don't keep checking.
            UserDefaults.standard.set(true, forKey: doneKey)
            UserDefaults.standard.removeObject(forKey: inProgressKey)
            return
        }

        let entries: [URL]
        do {
            entries = try FileManager.default
                .contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: [.isDirectoryKey])
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            UserDefaults.standard.set(true, forKey: doneKey)
            UserDefaults.standard.removeObject(forKey: inProgressKey)
            return
        }

        let importer = ImportService(modelContext: modelContext)

        for bookFolder in entries {
            await seed(bookFolder: bookFolder, importer: importer, context: modelContext)
        }

        UserDefaults.standard.set(true, forKey: doneKey)
        UserDefaults.standard.removeObject(forKey: inProgressKey)
    }

    /// Best-effort cleanup of a half-finished seed run from the previous
    /// launch. We can't tell which specific book got partially inserted
    /// without a per-book idempotency record, so we conservatively remove
    /// ALL books whose `importedAt` is within the last 5 minutes — the
    /// seed loader is the only thing that can have inserted a fresh book
    /// that close to the (still-running) launch sequence on a first
    /// install. User-imported books will not match because the user
    /// can't have completed a picker flow before this code runs.
    private static func rollbackPartialSeed(modelContext: ModelContext) {
        // SwiftData `#Predicate` capture of locally-bound variables is
        // unreliable — the SQLite translator sometimes evaluates the
        // captured expression at fetch time using a stale snapshot. Fetch
        // all books and filter in-memory; the bundle ships at most a
        // handful of seed books so the cost is negligible and the
        // semantics are bulletproof.
        let cutoff = Date.now.addingTimeInterval(-5 * 60)
        let descriptor = FetchDescriptor<Book>()
        guard let books = try? modelContext.fetch(descriptor) else { return }
        let recent = books.filter { $0.importedAt >= cutoff }
        for book in recent {
            modelContext.delete(book)
        }
        try? modelContext.save()
    }

    /// Look up `Resources/SeedBooks` inside the app bundle.
    private static func bundledFolderURL() -> URL? {
        if let url = Bundle.main.url(forResource: resourceFolder, withExtension: nil) {
            return url
        }
        // Folder-reference resources live as a regular sub-directory of the
        // bundle. Fall back to scanning the resourcePath directly.
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let candidate = URL(fileURLWithPath: resourcePath).appendingPathComponent(resourceFolder, isDirectory: true)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    private static func seed(bookFolder: URL, importer: ImportService, context: ModelContext) async {
        let metaURL = bookFolder.appendingPathComponent("meta.json")
        let meta: SeedMeta
        if let metaData = try? Data(contentsOf: metaURL),
           let parsed = try? JSONDecoder().decode(SeedMeta.self, from: metaData) {
            meta = parsed
        } else if let inferred = inferMeta(from: bookFolder) {
            // Partial generation (e.g. ran out of API credits) — synthesise
            // a meta.json from whatever .txt files are present so the user
            // still gets the original + any completed variants on the shelf.
            meta = inferred
        } else {
            return
        }

        // Avoid double-seeding when running on a partially-seeded device.
        if bookAlreadyImported(slug: meta.slug, context: context) {
            return
        }

        let epubURL = bookFolder.appendingPathComponent("original.epub")
        guard FileManager.default.fileExists(atPath: epubURL.path) else { return }

        // Copy the EPUB into a writable scratch path; the importer makes its
        // own canonical copy, so this temp lives only for the parse.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(meta.slug)-\(UUID().uuidString).epub")
        do {
            try? FileManager.default.removeItem(at: tempURL)
            try FileManager.default.copyItem(at: epubURL, to: tempURL)
        } catch {
            return
        }
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let book: Book
        do {
            book = try await importer.importBook(from: tempURL)
        } catch {
            return
        }

        // Override metadata with the curated values from meta.json so users
        // see "The Republic / Plato" rather than whatever the EPUB headers say.
        book.title = meta.title
        book.author = meta.author
        if !meta.categories.isEmpty { book.categoryTags = meta.categories }
        if !meta.themes.isEmpty     { book.detectedThemes = meta.themes }
        // `book.notes` is the user-facing notes field — leave it alone so
        // people can write their own. UserDefaults `SeedBooks.completed-v1`
        // is the actual idempotency guard.

        // Fallback cover when the parser didn't pick one up. Stored on
        // disk under `<bookFolder>/cover.jpg` instead of the @Model
        // `coverData` blob — matches the ImportService path so CloudKit
        // sync stays small for seeded rows too.
        if book.coverFilename.isEmpty, book.coverData == nil,
           let coverData = try? Data(contentsOf: bookFolder.appendingPathComponent("cover.jpg")) {
            BookStore.shared.writeCover(coverData, bookID: book.id)
            book.coverFilename = "cover.jpg"
        }

        // Pre-populated key learnings — created independently of variants so
        // every book has them on first launch even when the rest of the
        // generation pipeline didn't finish.
        seedLearnings(book: book, bookFolder: bookFolder)

        // Variants — one BookVariant per .txt file in meta.json. Body
        // text is written to disk under `<bookFolder>` and the @Model
        // row stores only the filename, mirroring the path
        // `ImportService` and `TransformationEngine` use for fresh
        // content.
        var addedCount = 0
        for v in meta.variants {
            let txtURL = bookFolder.appendingPathComponent(v.file)
            guard let txt = try? String(contentsOf: txtURL, encoding: .utf8), !txt.isEmpty else {
                print("[SeedBooks] missing/empty: \(v.file) for \(meta.slug)")
                continue
            }
            guard let kind = VariantKind(rawValue: v.kind) else {
                print("[SeedBooks] unknown kind \(v.kind) for \(meta.slug)/\(v.file)")
                continue
            }
            let variant = BookVariant(
                book: book,
                kind: kind,
                contentText: "",
                targetPages: v.target_pages,
                styleReference: v.style_reference,
                modelUsed: v.model
            )
            variant.inputTokens  = v.input_tokens ?? 0
            variant.outputTokens = v.output_tokens ?? 0
            variant.costUSD      = v.cost_usd ?? 0
            if BookStore.shared.writeVariantText(txt, bookID: book.id, variantID: variant.id) {
                variant.contentFilename = "variant-\(variant.id.uuidString).txt"
            } else {
                variant.contentText = txt
            }
            context.insert(variant)
            addedCount += 1
        }
        print("[SeedBooks] \(meta.slug): added \(addedCount) variants in addition to Original")

        do { try context.save() } catch {
            print("[SeedBooks] save failed for \(meta.slug): \(error)")
        }
    }

    /// Reads `learnings.json` (curated array of `{text, chapter}` records)
    /// from the book's seed folder and creates BOTH a `KeyLearning` row
    /// (kept for backwards compatibility with users who already have data)
    /// and an `Annotation` row, which is what the new Bookmarks gallery
    /// reads. Annotations show in the new tab as visually striking
    /// "highlight cards" — pre-seeding here means a fresh install opens
    /// to a populated gallery instead of an empty state.
    private static func seedLearnings(book: Book, bookFolder: URL) {
        let url = bookFolder.appendingPathComponent("learnings.json")
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([SeedLearning].self, from: data) else {
            return
        }
        let palette: [AnnotationColor] = [.yellow, .blue, .pink, .green, .purple]
        for (idx, entry) in entries.enumerated() {
            let learning = KeyLearning(
                book: book,
                text: entry.text,
                chapterRef: entry.chapter,
                userEdited: false
            )
            book.modelContext?.insert(learning)

            // Mirror as an Annotation — that's what the new Bookmarks tab
            // consumes. The chapter ref is stored in `note` so the card
            // can show "Chapter XVIII" beneath the highlight badge.
            let annotation = Annotation(
                book: book,
                variantID: nil,
                quotedText: entry.text,
                note: entry.chapter,
                color: palette[idx % palette.count]
            )
            book.modelContext?.insert(annotation)
        }
    }

    private static func bookAlreadyImported(slug: String, context: ModelContext) -> Bool {
        // The UserDefaults `SeedBooks.completed-v1` flag is the real
        // idempotency check. This function exists for future "re-import a
        // single seed book" flows. For now we always return false and let
        // the flag gate the loop in `runIfNeeded`.
        _ = slug
        _ = context
        return false
    }

    /// Recovers a usable `SeedMeta` from a book folder when its `meta.json`
    /// was never written (the API run was interrupted partway). Curated
    /// fallbacks for the three demo books cover the title / author /
    /// categories; the variants list is rebuilt from any `.txt` files
    /// actually present on disk.
    private static func inferMeta(from bookFolder: URL) -> SeedMeta? {
        let slug = bookFolder.lastPathComponent
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: bookFolder, includingPropertiesForKeys: nil
        ) else { return nil }

        guard let curated = curatedFallback(for: slug) else { return nil }

        var inferred: [SeedVariant] = []
        for url in entries where url.pathExtension.lowercased() == "txt" {
            let name = url.deletingPathExtension().lastPathComponent
            guard let v = curated.variantTemplates[name] else { continue }
            inferred.append(SeedVariant(
                file: url.lastPathComponent,
                kind: v.kind,
                target_pages: v.target_pages,
                style_reference: v.style_reference,
                model: v.model,
                input_tokens: nil,
                cached_input_tokens: nil,
                output_tokens: nil,
                cost_usd: nil
            ))
        }

        return SeedMeta(
            slug: slug,
            title: curated.title,
            author: curated.author,
            categories: curated.categories,
            themes: curated.themes,
            source_words: nil,
            source_pages_est: nil,
            variants: inferred
        )
    }

    /// Curated metadata for the three bundled demo books — used when the
    /// generation pipeline didn't finish writing a meta.json.
    private static func curatedFallback(for slug: String) -> CuratedSeed? {
        switch slug {
        case "republic-plato":
            return CuratedSeed(
                title: "The Republic", author: "Plato",
                categories: ["Philosophy"],
                themes: ["justice", "ideal state", "education", "the soul", "rulers"],
                variantTemplates: [
                    "compressed-25":   .init(kind: "compressed", target_pages: 25, style_reference: "",                  model: "claude-sonnet-4-6"),
                    "compressed-75":   .init(kind: "compressed", target_pages: 75, style_reference: "",                  model: "claude-sonnet-4-6"),
                    "restyled-gladwell": .init(kind: "styled",   target_pages: 75, style_reference: "Malcolm Gladwell",  model: "claude-opus-4-7"),
                ]
            )
        case "prince-machiavelli":
            return CuratedSeed(
                title: "The Prince", author: "Niccolò Machiavelli",
                categories: ["Philosophy", "Politics"],
                themes: ["power", "statecraft", "fortune", "virtue", "leadership"],
                variantTemplates: [
                    "compressed-10":   .init(kind: "compressed", target_pages: 10, style_reference: "",                  model: "claude-sonnet-4-6"),
                    "compressed-30":   .init(kind: "compressed", target_pages: 30, style_reference: "",                  model: "claude-sonnet-4-6"),
                    "restyled-harari": .init(kind: "styled",     target_pages: 25, style_reference: "Yuval Noah Harari", model: "claude-opus-4-7"),
                ]
            )
        case "beyond-good-evil-nietzsche":
            return CuratedSeed(
                title: "Beyond Good and Evil", author: "Friedrich Nietzsche",
                categories: ["Philosophy"],
                themes: ["morality", "the will to power", "truth", "religion", "self-overcoming"],
                variantTemplates: [
                    "compressed-20":  .init(kind: "compressed", target_pages: 20, style_reference: "",             model: "claude-sonnet-4-6"),
                    "compressed-60":  .init(kind: "compressed", target_pages: 60, style_reference: "",             model: "claude-sonnet-4-6"),
                    "restyled-didion": .init(kind: "styled",    target_pages: 50, style_reference: "Joan Didion",  model: "claude-opus-4-7"),
                ]
            )
        default:
            return nil
        }
    }
}

private struct CuratedSeed {
    let title: String
    let author: String
    let categories: [String]
    let themes: [String]
    let variantTemplates: [String: VariantTemplate]

    struct VariantTemplate {
        let kind: String
        let target_pages: Int
        let style_reference: String
        let model: String
    }
}

// MARK: - meta.json schema

private struct SeedMeta: Decodable {
    let slug: String
    let title: String
    let author: String
    let categories: [String]
    let themes: [String]
    let source_words: Int?
    let source_pages_est: Int?
    let variants: [SeedVariant]
}

private struct SeedLearning: Decodable {
    let text: String
    let chapter: String
}

private struct SeedVariant: Decodable {
    let file: String
    let kind: String                // matches VariantKind raw value
    let target_pages: Int
    let style_reference: String
    let model: String
    let input_tokens: Int?
    let cached_input_tokens: Int?
    let output_tokens: Int?
    let cost_usd: Double?
}
