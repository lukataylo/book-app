import Testing
import Foundation
import SwiftData
@testable import BookApp

/// The catalog ships two things per title: an original summary and the
/// public-domain work it summarises. These pin the relationship between
/// them, because getting it wrong is invisible — a book with a missing or
/// mis-slugged source text still opens, it just quietly has nothing but
/// the summary in it.
@MainActor
struct FullTextTests {

    /// Hosted unit tests: `Bundle.main` is the app bundle, where the
    /// folder references live.
    private func bundledFolder(_ name: String) throws -> URL {
        try #require(Bundle.main.url(forResource: name, withExtension: nil),
                     "\(name) folder missing from the app bundle")
    }

    private func slugs(in folder: URL, ext: String) throws -> Set<String> {
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        return Set(files.filter { $0.pathExtension == ext }.map { $0.deletingPathExtension().lastPathComponent })
    }

    /// A source text whose filename doesn't match a pack slug is dead
    /// weight in the bundle — it ships, and nothing ever reads it.
    @Test
    func everySourceTextBelongsToAPack() throws {
        let packs = try slugs(in: bundledFolder("SummaryPacks"), ext: "json")
        let texts = try slugs(in: bundledFolder("FullTexts"), ext: "txt")
        #expect(!texts.isEmpty)
        #expect(texts.subtracting(packs).isEmpty, "orphaned source texts: \(texts.subtracting(packs).sorted())")
    }

    /// Floor check only — the fetch script is what verifies a multi-part
    /// source arrived whole (it counts sections against the number it
    /// asked for and refuses a short result). This catches the cruder
    /// failure: a file that is present but essentially empty.
    @Test
    func everySourceTextIsAWholeBook() throws {
        let folder = try bundledFolder("FullTexts")
        for slug in try slugs(in: folder, ext: "txt").sorted() {
            let text = try String(contentsOf: folder.appendingPathComponent("\(slug).txt"), encoding: .utf8)
            let words = SummaryPackLoader.wordCount(text)
            // The shortest real work in the catalog is As a Man Thinketh
            // at ~7,500 words; anything under 5,000 is a truncated fetch.
            #expect(words > 5_000, "\(slug) is only \(words) words")
        }
    }

    /// The reader, chapter list and TTS all key off `# ` markers. A source
    /// text with none is one unbroken block the user can't navigate.
    @Test
    func everySourceTextHasChapterMarkers() throws {
        let folder = try bundledFolder("FullTexts")
        for slug in try slugs(in: folder, ext: "txt").sorted() {
            let text = try String(contentsOf: folder.appendingPathComponent("\(slug).txt"), encoding: .utf8)
            let headings = text.split(separator: "\n").filter { $0.hasPrefix("# ") }.count
            #expect(headings >= 3, "\(slug) has \(headings) chapter markers")
        }
    }

    /// The shape the loader has to produce: the work in the `.original`
    /// slot, the summary demoted beside it, and lengths taken from the
    /// text rather than a number in the JSON.
    @Test
    func seedingPutsTheWorkInTheOriginalSlot() async throws {
        let container = try ModelContainer.bookAppPreview()
        let context = container.mainContext
        // `meditations` is the first pack alphabetically that ships a
        // source text; any of them would do.
        let slug = "meditations"
        guard let source = SummaryPackLoader.fullText(for: slug) else {
            Issue.record("no bundled source text for \(slug)")
            return
        }

        let packURL = try bundledFolder("SummaryPacks").appendingPathComponent("\(slug).json")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let pack = try decoder.decode(SummaryPack.self, from: Data(contentsOf: packURL))

        #expect(SummaryPackLoader.seed(pack: pack, context: context))
        let book = try #require(try context.fetch(FetchDescriptor<Book>()).first)
        defer { BookStore.shared.deleteBookFolder(for: book.id) }

        let original = try #require(book.originalVariant)
        #expect(original.label.hasPrefix("Full text ·"))
        #expect(await original.loadText() == source)

        let summary = try #require((book.variants ?? []).first { $0.label.hasPrefix("The Big Ideas ·") })
        #expect(summary.kind == .compressed)
        #expect(await summary.loadText().hasPrefix(String(pack.summary.prefix(40))))

        // The book's length is the work's, because that is what the
        // Transformation Studio compresses from.
        #expect(book.totalWordsEstimate == SummaryPackLoader.wordCount(source))
        // …while the shelf still advertises the summary.
        #expect(book.readMinutesEstimate < 30)
    }

    /// The upgrade path for a device seeded before source texts shipped:
    /// the summary held the `.original` slot, and it has to be demoted in
    /// place — same row — so the highlights and reading position the user
    /// already has in it survive.
    @Test
    func attachingTheWorkDemotesTheSummaryInPlace() async throws {
        let container = try ModelContainer.bookAppPreview()
        let context = container.mainContext
        let slug = "meditations"
        guard let source = SummaryPackLoader.fullText(for: slug) else {
            Issue.record("no bundled source text for \(slug)")
            return
        }
        let packURL = try bundledFolder("SummaryPacks").appendingPathComponent("\(slug).json")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let pack = try decoder.decode(SummaryPack.self, from: Data(contentsOf: packURL))

        // Stand up the pre-upgrade shape by hand: summary as `.original`.
        let book = Book(title: pack.title, author: pack.sourceAuthor, format: .unknown)
        book.isSummaryEdition = true
        context.insert(book)
        defer { BookStore.shared.deleteBookFolder(for: book.id) }
        let summary = BookVariant(book: book, kind: .original)
        summary.label = "Summary"
        summary.writeText(pack.summary + "\n\n" + pack.attribution)
        context.insert(summary)
        let annotation = Annotation(book: book, variantID: summary.id,
                                    quotedText: "kept passage", note: "", color: .yellow)
        context.insert(annotation)
        try context.save()

        SummaryPackLoader.attachFullText(pack: pack, book: book, context: context)

        let original = try #require(book.originalVariant)
        #expect(original.label.hasPrefix("Full text ·"))
        #expect(await original.loadText() == source)

        // Same row, not a replacement — the id is unchanged and the
        // annotation still points at it.
        #expect(summary.kind == .compressed)
        #expect(summary.label.hasPrefix("The Big Ideas ·"))
        #expect(annotation.variantID == summary.id)
        #expect(book.annotations?.count == 1)

        // Running it twice must not stack a second copy of the work.
        SummaryPackLoader.attachFullText(pack: pack, book: book, context: context)
        #expect((book.variants ?? []).filter { $0.label.hasPrefix("Full text") }.count == 1)
    }

}
