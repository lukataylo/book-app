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
    /// Inline images extracted from the source. Reader paragraphs that
    /// originally contained an `<img>` are emitted as `[img:<filename>]`
    /// markers; this dictionary holds the bytes the importer should write
    /// into the book folder so the reader can load them by filename.
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
    var data: Data
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
    func parse(fileURL: URL) async throws -> ParsedBook
}
