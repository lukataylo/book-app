import Foundation
import SwiftData

/// Deepstash-style knowledge card — one snackable, self-contained idea from a
/// book. Cards arrive pre-curated with summary packs or are generated on
/// demand by `KnowledgeCardEngine`. Saving a card surfaces it in the Saved tab.
@Model
final class KnowledgeCard {
    var id: UUID = UUID()
    var book: Book?
    var title: String = ""
    var body: String = ""
    /// Display category: Principle, Mental Model, Habit, Insight, Warning, Practice.
    var category: String = ""
    /// Position within the book's deck.
    var order: Int = 0
    var saved: Bool = false
    var savedAt: Date?
    /// "seed" for pack-curated cards, "generated" for LLM output.
    var source: String = "seed"
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        book: Book? = nil,
        title: String,
        body: String,
        category: String = "",
        order: Int = 0,
        source: String = "seed"
    ) {
        self.id = id
        self.book = book
        self.title = title
        self.body = body
        self.category = category
        self.order = order
        self.source = source
        self.createdAt = .now
    }
}
