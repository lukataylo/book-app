import Foundation
import SwiftData

/// Orchestrates the full import flow:
///
/// 1. Copy file → iCloud-backed Documents container
/// 2. Run the right parser (or convert MOBI → EPUB first)
/// 3. Persist `Book` + `BookVariant(.original)` in SwiftData
/// 4. Kick off a background local-LLM job to auto-tag categories + themes
///
/// Anything that fails surfaces as an `ImportError` so the UI can show a
/// clear toast instead of a generic system error.
@MainActor
final class ImportService {
    private let modelContext: ModelContext
    private let store = BookStore.shared
    private let router = LLMRouter.shared

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    enum ImportError: Error, LocalizedError {
        case unknownFormat(String)
        case parserFailed(Error)
        case persistFailed(Error)

        var errorDescription: String? {
            switch self {
            case .unknownFormat(let ext): return "Unknown format: .\(ext)"
            case .parserFailed(let e):    return "Couldn't read book: \(e.localizedDescription)"
            case .persistFailed(let e):   return "Couldn't save: \(e.localizedDescription)"
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

        // MOBI: convert to EPUB once, then treat the EPUB as the canonical original.
        let parser: BookParser
        let parsedURL: URL
        let parsedFormat: BookFormat
        switch format {
        case .epub:
            parser = EPUBParser()
            parsedURL = storedURL
            parsedFormat = .epub
        case .pdf:
            parser = PDFParser()
            parsedURL = storedURL
            parsedFormat = .pdf
        case .mobi:
            do {
                let epubURL = try await MOBIConverter().convert(storedURL)
                parser = EPUBParser()
                parsedURL = epubURL
                parsedFormat = .epub
            } catch {
                throw ImportError.parserFailed(error)
            }
        case .unknown:
            throw ImportError.unknownFormat(sourceURL.pathExtension)
        }

        // EPUBParser streams image bytes directly into the book's
        // images folder when a destination is supplied — avoids buffering
        // 50–100 MB of bitmap data in `[ParsedImage]` for image-heavy
        // books.
        let imagesDir = store.imagesFolder(for: bookID)
        let parsed: ParsedBook
        do {
            parsed = try await parser.parse(fileURL: parsedURL, imagesDirectory: imagesDir)
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
        // a 200KB JPEG plus megabytes of text on every change. The
        // legacy in-row fields are left empty for new imports — older
        // installs may still have data in them and `BlobMigration`
        // moves it onto disk on next launch.
        if let coverData = parsed.coverData, !coverData.isEmpty {
            store.writeCover(coverData, bookID: bookID)
        }

        let book = Book(
            id: bookID,
            title: parsed.title,
            author: parsed.author,
            format: parsedFormat,
            coverData: nil,
            originalFileBookmark: bookmark
        )
        if parsed.coverData != nil {
            book.coverFilename = "cover.jpg"
        }
        book.totalPagesEstimate = parsed.totalPagesEstimate
        book.totalWordsEstimate = parsed.totalWords
        book.languageCode = parsed.languageCode

        let variant = BookVariant(
            book: book,
            kind: .original,
            contentText: "",
            contentBookmark: bookmark
        )
        // Write the body text now that we know the variant's ID, so
        // the file matches the deterministic URL `loadText()` resolves.
        if store.writeVariantText(parsed.fullText, bookID: bookID, variantID: variant.id) {
            variant.contentFilename = "variant-\(variant.id.uuidString).txt"
        } else {
            // Disk write failed (rare; permissions, full disk). Keep
            // the body in-row as a fallback so the book is still
            // readable, even if CloudKit balks.
            variant.contentText = parsed.fullText
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
        let sampleSnippet = String(parsed.fullText.prefix(2_000))
        let bookID = book.id
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
        case "mobi", "azw", "azw3": return .mobi
        default:                  return .unknown
        }
    }

    /// Best-effort auto-tagging. Runs the local LLM, parses the JSON reply,
    /// re-fetches the book from SwiftData (so we don't write to an
    /// orphaned instance if the user deleted the book during the call)
    /// and writes back to the same context. Silent on failure — tags can
    /// be edited manually later.
    private func autoTag(bookID: UUID, sample: String, title: String, author: String) async {
        let (system, user) = PromptTemplates.categoryTagging(title: title, author: author, sample: sample)
        let req = LLMRequest(system: system, user: user, maxOutputTokens: 512,
                             temperature: 0.2, model: .appleFoundation)
        do {
            let resp = try await router.run(.categoryTagging, request: req,
                                            sourceTokens: Chunker.tokenEstimate(sample))
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
