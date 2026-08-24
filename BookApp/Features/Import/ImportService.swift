import Foundation
import SwiftData

/// Orchestrates the full import flow:
///
/// 1. Copy file → iCloud-backed Documents container
/// 2. Run the right parser
/// 3. Persist `Book` + `BookVariant(.original)` in SwiftData
/// 4. Kick off a background local-LLM job to auto-tag categories + themes
///
/// Anything that fails surfaces as an `ImportError` so the UI can show a
/// clear toast instead of a generic system error.
@MainActor
final class ImportService {
    private let modelContext: ModelContext
    private let store = BookStore.shared

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    enum ImportError: Error, LocalizedError {
        case unknownFormat(String)
        case parserFailed(Error)
        case persistFailed(Error)
        case couldNotWrite

        var errorDescription: String? {
            switch self {
            case .unknownFormat(let ext): return "Unknown format: .\(ext)"
            case .parserFailed(let e):    return "Couldn't read book: \(e.localizedDescription)"
            case .persistFailed(let e):   return "Couldn't save: \(e.localizedDescription)"
            case .couldNotWrite:          return "Couldn't write the book to storage. Check available space."
            }
        }
    }

    /// Import one file. Returns the persisted `Book`.
    @discardableResult
    func importBook(from sourceURL: URL) async throws -> Book {
        let format = detectFormat(sourceURL)
        guard format != .unknown else {
            throw ImportError.unknownFormat(sourceURL.pathExtension)
        }

        let bookID = UUID()
        let (storedURL, bookmark) = try store.ingestOriginal(from: sourceURL, bookID: bookID, format: format)

        // `parsedURL` / `parsedFormat` used to differ from the stored
        // file: MOBI was converted to a sibling EPUB first, and the book
        // was recorded as an EPUB. With that gone the file we store is
        // the file we parse.
        let parser: BookParser
        switch format {
        case .epub:    parser = EPUBParser()
        case .pdf:     parser = PDFParser()
        case .unknown: throw ImportError.unknownFormat(sourceURL.pathExtension)
        }

        // EPUBParser streams image bytes directly into the book's
        // images folder when a destination is supplied — avoids buffering
        // 50–100 MB of bitmap data in `[ParsedImage]` for image-heavy
        // books.
        let imagesDir = store.imagesFolder(for: bookID)
        let parsed: ParsedBook
        do {
            parsed = try await parser.parse(fileURL: storedURL, imagesDirectory: imagesDir)
        } catch {
            throw ImportError.parserFailed(error)
        }

        // Any `ParsedImage` that still carries `data` is one the parser
        // couldn't stream (e.g. PDFs, or EPUB write failure). Write
        // those out now so the reader can resolve `[img:<name>]` markers.
        for img in parsed.images {
            guard let bytes = img.data else { continue }
            let dest = imagesDir.appendingPathComponent(img.filename)
            try? bytes.write(to: dest, options: .atomic)
        }

        // Cover and body text live on disk under `<bookFolder>` so the
        // SwiftData record stays small and CloudKit sync isn't dragging
        // a 200KB JPEG plus megabytes of text on every change.
        var wroteCover = false
        if let coverData = parsed.coverData, !coverData.isEmpty {
            wroteCover = store.writeCover(coverData, bookID: bookID)
        }

        let book = Book(
            id: bookID,
            title: parsed.title,
            author: parsed.author,
            format: format,
            originalFileBookmark: bookmark
        )
        book.hasCoverImage = wroteCover
        book.totalPagesEstimate = parsed.totalPagesEstimate
        book.totalWordsEstimate = parsed.totalWords
        book.languageCode = parsed.languageCode

        let variant = BookVariant(
            book: book,
            kind: .original,
            contentBookmark: bookmark
        )
        // Write the body text now that we know the variant's ID, so
        // the file matches the deterministic URL `loadText()` resolves.
        // A failed write means an unreadable book, so refuse the import
        // rather than inserting a row with nothing behind it.
        guard store.writeVariantText(parsed.fullText, bookID: bookID, variantID: variant.id) else {
            store.deleteBookFolder(for: bookID)
            throw ImportError.couldNotWrite
        }

        modelContext.insert(book)
        modelContext.insert(variant)
        do {
            try modelContext.save()
        } catch {
            throw ImportError.persistFailed(error)
        }

        // Auto-tag categories asynchronously. We capture the book's UUID
        // (a Sendable value) rather than the model object itself, so a
        // user deleting the book mid-tag doesn't leave us writing to an
        // orphaned instance. The Task re-fetches by ID and bails when
        // the book is gone.
        // `bookID` is already in scope from the start of this function —
        // same UUID used to seed the Book. No need to re-bind it.
        let sampleSnippet = String(parsed.fullText.prefix(2_000))
        let title = parsed.title
        let author = parsed.author
        Task { [weak self] in
            guard let self else { return }
            await self.autoTag(bookID: bookID, sample: sampleSnippet,
                               title: title, author: author)
        }

        return book
    }

    private func detectFormat(_ url: URL) -> BookFormat {
        switch url.pathExtension.lowercased() {
        case "epub":              return .epub
        case "pdf":               return .pdf
        default:                  return .unknown
        }
    }

    /// Best-effort auto-tagging, **on-device only**.
    ///
    /// This deliberately calls `LocalProvider` instead of going through
    /// `LLMRouter`: the router would fall through to Anthropic on any
    /// device without Apple Intelligence, which would put a sample of a
    /// book the user just imported onto the network with no prompt and no
    /// UI at all. Tagging is a convenience that already fails silently, so
    /// it is never worth a transmission — on a device that can't do it
    /// locally, the book simply arrives untagged and the user can edit the
    /// tags by hand.
    private func autoTag(bookID: UUID, sample: String, title: String, author: String) async {
        let (system, user) = PromptTemplates.categoryTagging(title: title, author: author, sample: sample)
        let req = LLMRequest(system: system, user: user, maxOutputTokens: 512,
                             temperature: 0.2, model: .appleFoundation)
        let local = LocalProvider()
        guard await local.isAvailable() else { return }
        do {
            let resp = try await local.complete(req)
            applyTags(toBookID: bookID, from: resp.text)
        } catch {
            // Tagging is best-effort — silently fail.
        }
    }

    private func applyTags(toBookID id: UUID, from json: String) {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.id == id }
        )
        guard let book = try? modelContext.fetch(descriptor).first else { return }
        let categories = payload["categories"] as? [String] ?? []
        let themes = payload["themes"] as? [String] ?? []
        book.categoryTags = categories
        book.detectedThemes = themes
        try? modelContext.save()
    }
}
