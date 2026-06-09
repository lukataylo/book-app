import Foundation
import Testing
import SwiftData
@testable import BookApp

/// Seeding contract for the summary catalog: a pack produces the full
/// Read/Remember/Act graph, and seeding is idempotent even when the
/// UserDefaults flag is lost (the CloudKit duplicate guard).
@MainActor
struct SummaryPackLoaderTests {

    private func makePack(slug: String = "test-pack") -> SummaryPack {
        SummaryPack(
            slug: slug,
            title: "The Big Ideas in Testing",
            sourceTitle: "Testing",
            sourceAuthor: "A. Author",
            sourceYear: 2020,
            categories: ["Science"],
            themes: ["unit testing"],
            readMinutes: 12,
            attribution: "An original summary of the ideas in Testing by A. Author (2020). Not affiliated with or endorsed by the author or publisher. If these ideas resonate, buy the full book.",
            summary: "Intro.\n\n# One\n\nBody paragraph.",
            learnings: [.init(text: "A learning.", chapter: "One")],
            cards: [.init(title: "A Card", body: "A body.", category: "Insight")],
            actions: [.init(title: "Do a thing", detail: "How.", kind: "event", day: 2, durationMinutes: 30)]
        )
    }

    @Test
    func seedCreatesTheFullGraph() throws {
        let container = try ModelContainer.bookAppPreview()
        let context = container.mainContext

        #expect(SummaryPackLoader.seed(pack: makePack(), context: context))

        let books = try context.fetch(FetchDescriptor<Book>())
        #expect(books.count == 1)
        let book = try #require(books.first)
        #expect(book.isSummaryEdition)
        #expect(book.readMinutesEstimate == 12)
        #expect(book.sourceAttribution.contains("Not affiliated"))
        // The summary is stored as the .original variant so every reading
        // feature works on it; attribution leads the text.
        #expect(book.originalVariant?.label == "Summary")
        #expect(book.originalVariant?.contentText.hasPrefix("An original summary") == true)
        #expect(book.keyLearnings?.count == 1)
        #expect(book.knowledgeCards?.count == 1)
        #expect(book.actionItems?.count == 1)
        let action = try #require(book.actionItems?.first)
        #expect(action.kind == .event)
        #expect(action.dayOffset == 2)
        #expect(action.durationMinutes == 30)
    }

    @Test
    func seedingTwiceDoesNotDuplicate() throws {
        let container = try ModelContainer.bookAppPreview()
        let context = container.mainContext

        #expect(SummaryPackLoader.seed(pack: makePack(), context: context))
        // Second call simulates a device whose UserDefaults flag was lost
        // (or a second device whose store synced down via CloudKit).
        #expect(SummaryPackLoader.seed(pack: makePack(), context: context))

        let books = try context.fetch(FetchDescriptor<Book>())
        #expect(books.count == 1)
        #expect(books.first?.knowledgeCards?.count == 1)
    }
}
