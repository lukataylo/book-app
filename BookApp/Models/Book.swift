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
    var coverData: Data?
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
    /// True for catalog titles that ship as original BookApp summaries
    /// ("The Big Ideas in …") rather than user-imported files.
    var isSummaryEdition: Bool = false
    /// Legal attribution line shown for summary editions
    /// ("An original summary of the ideas in … Not affiliated with …").
    var sourceAttribution: String = ""
    /// Estimated minutes to read the summary edition (0 for imported books).
    var readMinutesEstimate: Int = 0

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

    @Relationship(deleteRule: .cascade, inverse: \KnowledgeCard.book)
    var knowledgeCards: [KnowledgeCard]? = []

    @Relationship(deleteRule: .cascade, inverse: \ActionItem.book)
    var actionItems: [ActionItem]? = []

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
}
