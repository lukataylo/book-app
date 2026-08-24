import Foundation
import SwiftData

enum BookFormat: String, Codable, CaseIterable, Sendable {
    case epub
    case pdf
    case unknown
}

@Model
final class Book {
    /// Logical id, populated at insertion. CloudKit-private databases reject
    /// unique constraints, so uniqueness is enforced by construction (UUIDs).
    var id: UUID = UUID()
    var title: String = ""
    var author: String = ""
    /// True once a cover image has been written to
    /// `BookStore.shared.coverURL(bookID:)`. The URL is deterministic, so
    /// this is the only cover state the row needs to carry.
    var hasCoverImage: Bool = false
    var formatRaw: String = BookFormat.unknown.rawValue
    var originalFileBookmark: Data?
    var totalPagesEstimate: Int = 0
    var totalWordsEstimate: Int = 0
    var languageCode: String?
    var categoryTags: [String] = []
    var detectedThemes: [String] = []
    var importedAt: Date = Date.now
    var lastOpenedAt: Date?
    var notes: String = ""
    /// True for catalog titles that ship as original BookApp summaries
    /// ("The Big Ideas in …") rather than user-imported files.
    var isSummaryEdition: Bool = false
    /// Legal attribution line shown for summary editions
    /// ("An original summary of the ideas in … Not affiliated with …").
    var sourceAttribution: String = ""
    /// Estimated minutes to read the summary edition (0 for imported books).
    var readMinutesEstimate: Int = 0
    /// Slug naming this book's designed vector cover in `Covers.xcassets`
    /// (asset name `cover-<artSlug>`). Set by the loaders from the pack /
    /// seed slug. Empty → fall back to the generated Idea-Glyph cover.
    /// Additive + defaulted, so it migrates cleanly into existing stores.
    var artSlug: String = ""

    @Relationship(deleteRule: .cascade, inverse: \BookVariant.book)
    var variants: [BookVariant]? = []

    @Relationship(deleteRule: .cascade, inverse: \Annotation.book)
    var annotations: [Annotation]? = []

    @Relationship(deleteRule: .cascade, inverse: \ReadingProgress.book)
    var progress: [ReadingProgress]? = []

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.book)
    var bookmarks: [Bookmark]? = []

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        format: BookFormat,
        originalFileBookmark: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.formatRaw = format.rawValue
        self.originalFileBookmark = originalFileBookmark
        self.importedAt = .now
    }

    var format: BookFormat {
        get { BookFormat(rawValue: formatRaw) ?? .unknown }
        set { formatRaw = newValue.rawValue }
    }

    var originalVariant: BookVariant? {
        variants?.first { $0.kind == .original }
    }

    /// Cover image bytes for synchronous consumers (e.g. Now-Playing
    /// artwork). A single `Data(contentsOf:)` — fine for cover-sized
    /// images, but UI layers (cards, detail page) should still go
    /// through the async `CoverImageCache` so the JPEG decode stays off
    /// the main thread.
    func coverImageData() -> Data? {
        guard hasCoverImage else { return nil }
        return try? Data(contentsOf: BookStore.shared.coverURL(bookID: id))
    }
}
