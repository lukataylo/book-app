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
