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
        guard let metaData = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(SeedMeta.self, from: metaData) else {
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
