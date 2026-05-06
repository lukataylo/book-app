import Foundation
import SwiftData

@Model
final class Bookmark {
    var id: UUID = UUID()
    var book: Book?
    var variantID: UUID?
    var paragraphIndex: Int = 0
    /// Optional user-supplied label. When empty the UI falls back to the
    /// first sentence of the bookmarked paragraph.
    var label: String = ""
    /// Snippet of the paragraph at bookmark time so the list view doesn't
    /// have to fetch the variant body to show context.
    var snippet: String = ""
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        book: Book? = nil,
        variantID: UUID? = nil,
        paragraphIndex: Int = 0,
        label: String = "",
        snippet: String = ""
    ) {
        self.id = id
        self.book = book
        self.variantID = variantID
        self.paragraphIndex = paragraphIndex
        self.label = label
        self.snippet = snippet
        self.createdAt = .now
    }
}
