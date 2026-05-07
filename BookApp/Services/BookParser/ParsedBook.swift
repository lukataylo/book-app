import Foundation

/// Output of any book parser. Holds metadata + the full plain-text body
/// (used by the LLM stack and TTS) plus a structured chapter index for the
/// reader and key-learnings extraction.
struct ParsedBook: Sendable {
    var title: String
    var author: String
    var languageCode: String?
    var coverData: Data?
    var chapters: [ParsedChapter]
    var fullText: String
    var format: BookFormat
    /// Inline images extracted from the source. The new EPUB code path
    /// streams bytes directly to disk during parse and returns
    /// filename-only entries here, so an image-heavy book doesn't
    /// buffer 50–100 MB of bitmap data in `[ParsedImage]` before the
    /// importer writes it back out. Older parsers (PDF) still populate
    /// `data`; the importer treats both shapes uniformly.
    var images: [ParsedImage] = []

    var totalWords: Int {
        fullText.split(whereSeparator: { $0.isWhitespace }).count
    }

    var totalPagesEstimate: Int {
        // ~250 words per printed page is a common heuristic.
        max(1, totalWords / 250)
    }
}

struct ParsedChapter: Sendable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var text: String
    var locator: String     // opaque ref usable by the reader to jump back
}

struct ParsedImage: Sendable {
    /// Filename only — the importer writes the bytes to
    /// `<bookFolder>/images/<filename>`.
    var filename: String
    /// Either the raw bytes (legacy / PDF path), or `nil` when the
    /// parser already wrote the file directly into the book folder
    /// (new EPUB streaming path). When `nil` the importer should not
    /// write again.
    var data: Data?

    init(filename: String, data: Data? = nil) {
        self.filename = filename
        self.data = data
    }
}

enum ParserError: Error, LocalizedError {
    case unsupportedFormat(String)
    case fileUnreadable(String)
    case decodingFailed(String)
    case mobiConversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let f):     return "Unsupported format: \(f)"
        case .fileUnreadable(let m):        return "Couldn't read file: \(m)"
        case .decodingFailed(let m):        return "Couldn't decode book: \(m)"
        case .mobiConversionFailed(let m):  return "MOBI conversion failed: \(m)"
        }
    }
}

protocol BookParser: Sendable {
    /// Parse a book file. `imagesDirectory`, when non-nil, lets the
    /// parser stream extracted images directly to disk instead of
    /// buffering bytes in `ParsedImage.data`. Parsers that don't extract
    /// images (PDF) can ignore the parameter; parsers that do (EPUB)
    /// should write into the directory and return filename-only
    /// `ParsedImage` entries.
    func parse(fileURL: URL, imagesDirectory: URL?) async throws -> ParsedBook
}

extension BookParser {
    /// Backwards-compatible overload that buffers images in memory.
    func parse(fileURL: URL) async throws -> ParsedBook {
        try await parse(fileURL: fileURL, imagesDirectory: nil)
    }
}
