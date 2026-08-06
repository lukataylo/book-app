import Foundation
import Testing
import SwiftData
@testable import BookApp

/// Seeding contract for the summary catalog: a pack produces the book,
/// its variants and learnings, and seeding is idempotent even when the
/// UserDefaults flag is lost (the CloudKit duplicate guard).
@MainActor
struct SummaryPackLoaderTests {

    private func makePack(slug: String = "test-pack") -> SummaryPack {
        SummaryPack(
            slug: slug,
            title: "The Big Ideas in Testing",
            sourceAuthor: "A. Author",
            sourceYear: 2020,
            categories: ["Science"],
            themes: ["unit testing"],
            readMinutes: 12,
            attribution: "An original summary of the ideas in Testing by A. Author (2020). Not affiliated with or endorsed by the author or publisher. If these ideas resonate, buy the full book.",
            summary: "Intro.\n\n# One\n\nBody paragraph.",
            summaryShort: "A quick gist paragraph.",
            learnings: [.init(text: "A learning.", chapter: "One")],
            styledVariants: [.init(label: "As a limerick", style: "Told as a limerick", text: "There once was a pack from a test.")]
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
        // feature works on it; attribution closes the text (leading with
        // it would make Listen narrate boilerplate first).
        #expect(book.originalVariant?.label == "Summary")
        #expect(book.originalVariant?.contentText.hasPrefix("Intro.") == true)
        #expect(book.originalVariant?.contentText.hasSuffix("buy the full book.") == true)
        // The quick take ships as a second, compressed length tier.
        let quickTake = (book.variants ?? []).first { $0.label == SummaryPackLoader.quickTakeLabel }
        #expect(quickTake != nil)
        #expect(quickTake?.kind == .compressed)
        #expect(quickTake?.contentText.contains("A quick gist paragraph.") == true)
        #expect(book.annotations?.count == 1)
        // Bundled comic re-style attaches as its own .styled variant.
        let styled = (book.variants ?? []).filter { $0.kind == .styled }
        #expect(styled.count == 1)
        #expect(styled.first?.label == "As a limerick")
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
        #expect(books.first?.annotations?.count == 1)
        // The duplicate pass must not double the quick-take variant either.
        let quickTakes = (books.first?.variants ?? []).filter { $0.label == SummaryPackLoader.quickTakeLabel }
        #expect(quickTakes.count == 1)
        // …nor the bundled re-style.
        #expect((books.first?.variants ?? []).filter { $0.kind == .styled }.count == 1)
    }

    @Test
    func quickTakeBackfillsBooksSeededBeforeItExisted() throws {
        let container = try ModelContainer.bookAppPreview()
        let context = container.mainContext

        // Seed a pack from before the quick-take tier shipped…
        var pack = makePack()
        pack = SummaryPack(
            slug: pack.slug, title: pack.title,
            sourceAuthor: pack.sourceAuthor, sourceYear: pack.sourceYear,
            categories: pack.categories, themes: pack.themes,
            readMinutes: pack.readMinutes, attribution: pack.attribution,
            summary: pack.summary, summaryShort: nil,
            learnings: pack.learnings, styledVariants: pack.styledVariants
        )
        #expect(SummaryPackLoader.seed(pack: pack, context: context))
        var books = try context.fetch(FetchDescriptor<Book>())
        #expect((books.first?.variants ?? []).allSatisfy { $0.label != SummaryPackLoader.quickTakeLabel })

        // …then re-seed with the updated pack: the gist attaches to the
        // existing book instead of duplicating it.
        #expect(SummaryPackLoader.seed(pack: makePack(), context: context))
        books = try context.fetch(FetchDescriptor<Book>())
        #expect(books.count == 1)
        let quickTakes = (books.first?.variants ?? []).filter { $0.label == SummaryPackLoader.quickTakeLabel }
        #expect(quickTakes.count == 1)
    }
}

/// Withdrawing a title from the bundle has to remove it from devices that
/// already seeded it. Without this the loader only ever grew the catalog:
/// ~50 in-copyright summaries stayed installed and readable after being
/// pulled from the repo, which was the whole point of pulling them.
@MainActor
struct SummaryPackPruneTests {

    private func book(_ title: String, slug: String = "", summary: Bool = true) -> Book {
        let b = Book(title: title, author: "A", format: .unknown)
        b.isSummaryEdition = summary
        b.artSlug = slug
        return b
    }

    @Test
    func withdrawnTitlesAreRemovedAndTheRestKept() throws {
        let container = try ModelContainer.bookAppPreview()
        let ctx = container.mainContext

        let shipping   = book("The Big Ideas in The Art of War", slug: "the-art-of-war")
        let withdrawn  = book("The Big Ideas in Atomic Habits", slug: "atomic-habits")
        // Seeded before `artSlug` existed, so it can only be matched by title.
        let legacy     = book("The Big Ideas in Dare to Lead")
        let userImport = book("My Own EPUB", summary: false)
        for b in [shipping, withdrawn, legacy, userImport] { ctx.insert(b) }
        try ctx.save()

        let bundled = [URL(fileURLWithPath: "/packs/the-art-of-war.json")]
        SummaryPackLoader.pruneWithdrawn(bundled: bundled, context: ctx)

        let titles = Set(try ctx.fetch(FetchDescriptor<Book>()).map(\.title))
        #expect(titles.contains("The Big Ideas in The Art of War"))
        #expect(titles.contains("My Own EPUB"), "user imports are never in scope")
        #expect(!titles.contains("The Big Ideas in Atomic Habits"))
        #expect(!titles.contains("The Big Ideas in Dare to Lead"), "matched by title, not slug")
    }

    @Test
    func anEmptyBundleNeverPrunes() throws {
        let container = try ModelContainer.bookAppPreview()
        let ctx = container.mainContext
        ctx.insert(book("The Big Ideas in The Art of War", slug: "the-art-of-war"))
        try ctx.save()

        // A failed directory read must not be read as "everything withdrawn".
        SummaryPackLoader.pruneWithdrawn(bundled: [], context: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Book>()).count == 1)
    }
}
