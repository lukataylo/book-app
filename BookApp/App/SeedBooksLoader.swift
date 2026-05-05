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

    static func runIfNeeded(modelContext: ModelContext) async {
        if UserDefaults.standard.bool(forKey: doneKey) { return }

        guard let resourceURL = bundledFolderURL() else {
            // Bundle missing — likely Debug build with no seed assets. Mark
            // done so we don't keep checking.
            UserDefaults.standard.set(true, forKey: doneKey)
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
            return
        }

        let importer = ImportService(modelContext: modelContext)

        for bookFolder in entries {
            await seed(bookFolder: bookFolder, importer: importer, context: modelContext)
        }

        UserDefaults.standard.set(true, forKey: doneKey)
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

        // Fallback cover when the parser didn't pick one up.
        if book.coverData == nil,
           let coverData = try? Data(contentsOf: bookFolder.appendingPathComponent("cover.jpg")) {
            book.coverData = coverData
        }

        // Variants — one BookVariant per .txt file in meta.json.
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
                contentText: txt,
                targetPages: v.target_pages,
                styleReference: v.style_reference,
                modelUsed: v.model
            )
            variant.inputTokens  = v.input_tokens ?? 0
            variant.outputTokens = v.output_tokens ?? 0
            variant.costUSD      = v.cost_usd ?? 0
            context.insert(variant)
            addedCount += 1
        }
        print("[SeedBooks] \(meta.slug): added \(addedCount) variants in addition to Original")

        do { try context.save() } catch {
            print("[SeedBooks] save failed for \(meta.slug): \(error)")
        }
    }

    private static func bookAlreadyImported(slug: String, context: ModelContext) -> Bool {
        // We don't store slug on Book directly. Approximate by matching title +
        // author of the curated meta — good enough since these are seeded
        // exactly once per device.
        let descriptor = FetchDescriptor<Book>()
        guard let books = try? context.fetch(descriptor) else { return false }
        return books.contains { $0.notes.contains("seed:\(slug)") }
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
