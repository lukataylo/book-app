import Foundation
import SwiftData

enum BookFormat: String, Codable, CaseIterable, Sendable {
    case epub
    case pdf
    case mobi
    case unknown
}

@Model
final class Book {
    /// Logical id, populated at insertion. CloudKit-private databases reject
    /// unique constraints, so uniqueness is enforced by construction (UUIDs).
    var id: UUID = UUID()
    var title: String = ""
    var author: String = ""
    /// Legacy in-row cover bytes. Kept for backwards compatibility with
    /// existing CloudKit data; new books leave this `nil` and store the
    /// cover at `BookStore.shared.coverURL(bookID:)`. `BlobMigration`
    /// moves any non-nil values onto disk and clears them on first
    /// launch after the upgrade — keeping a 200KB JPEG in a CloudKit
    /// record bumps every sync into the slow path.
    var coverData: Data?
    /// Filename within `<bookFolder>` that holds the cover when the
    /// new disk-backed path is in use. Empty string means "fall back to
    /// `coverData`".
    var coverFilename: String = ""
    var formatRaw: String = BookFormat.unknown.rawValue
    var originalFileBookmark: Data?
    var totalPagesEstimate: Int = 0
    var totalWordsEstimate: Int = 0
    var languageCode: String?
    var categoryTags: [String] = []
    var detectedThemes: [String] = []
    var importedAt: Date = Date.now
    var lastOpenedAt: Date?
    var rating: Int = 0
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \BookVariant.book)
    var variants: [BookVariant]? = []

    @Relationship(deleteRule: .cascade, inverse: \KeyLearning.book)
    var keyLearnings: [KeyLearning]? = []

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
        coverData: Data? = nil,
        originalFileBookmark: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.formatRaw = format.rawValue
        self.coverData = coverData
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

    var nonOriginalVariants: [BookVariant] {
        (variants ?? []).filter { $0.kind != .original }
    }

    /// Cover image bytes for synchronous consumers (e.g. Now-Playing
    /// artwork). Prefers the in-row `coverData` if a legacy / test row
    /// has it, otherwise reads from disk. The disk read is a single
    /// `Data(contentsOf:)` — fine for cover-sized images, but UI layers
    /// (cards, detail page) should still go through the async
    /// `CoverImageCache` so the JPEG decode stays off the main thread.
    func coverImageData() -> Data? {
        if let inRow = coverData, !inRow.isEmpty { return inRow }
        let url = BookStore.shared.coverURL(bookID: id)
        return try? Data(contentsOf: url)
    }
}
