import Testing
import Foundation
import SwiftData
@testable import BookApp

/// Resume-on-open used to be silently broken — `ReaderViewModel.init`
/// hardcoded `currentParagraph = 0` and the `locator` we wrote ("scroll:")
/// was never read back. v12 changed both ends. These tests pin the
/// translation so a future refactor doesn't quietly regress it.
@MainActor
struct ReaderResumeTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Book.self, BookVariant.self, KeyLearning.self,
            Annotation.self, ReadingProgress.self, Bookmark.self,
            ReaderSettings.self, TTSSettings.self, SpeedReaderSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test
    func paragraphLocatorRestoresExactPosition() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let book = Book(title: "Test", author: "Author", format: .epub, coverData: nil)
        let body = (0..<10).map { "Paragraph \($0)." }.joined(separator: "\n\n")
        let variant = BookVariant(book: book, kind: .original, contentText: body)
        context.insert(book)
        context.insert(variant)

        let progress = ReadingProgress(book: book, variantID: variant.id,
                                       locator: "para:7", percent: 0.7)
        context.insert(progress)
        try context.save()

        let vm = ReaderViewModel(book: book, variant: variant)
        #expect(vm.currentParagraph == 7)
    }

    @Test
    func legacyScrollLocatorFallsBackToPercentEstimate() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let book = Book(title: "Test", author: "Author", format: .epub, coverData: nil)
        let body = (0..<20).map { "P\($0)" }.joined(separator: "\n\n")
        let variant = BookVariant(book: book, kind: .original, contentText: body)
        context.insert(book)
        context.insert(variant)

        // Pre-v12 locator format. Falls back to percent × paragraph count.
        let progress = ReadingProgress(book: book, variantID: variant.id,
                                       locator: "scroll:500000", percent: 0.5)
        context.insert(progress)
        try context.save()

        let vm = ReaderViewModel(book: book, variant: variant)
        // 50% of 20 paragraphs ≈ paragraph 10
        #expect(vm.currentParagraph == 10)
    }

    @Test
    func noProgressMeansFreshOpenAtTop() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let book = Book(title: "Test", author: "Author", format: .epub, coverData: nil)
        let body = "Just one paragraph."
        let variant = BookVariant(book: book, kind: .original, contentText: body)
        context.insert(book)
        context.insert(variant)
        try context.save()

        let vm = ReaderViewModel(book: book, variant: variant)
        #expect(vm.currentParagraph == 0)
    }

    @Test
    func outOfRangeLocatorClamps() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let book = Book(title: "Test", author: "Author", format: .epub, coverData: nil)
        // 3 paragraphs, locator points way past the end (e.g. variant
        // shrank after a re-transform).
        let body = "P0\n\nP1\n\nP2"
        let variant = BookVariant(book: book, kind: .original, contentText: body)
        context.insert(book)
        context.insert(variant)
        let progress = ReadingProgress(book: book, variantID: variant.id,
                                       locator: "para:999", percent: 1.0)
        context.insert(progress)
        try context.save()

        let vm = ReaderViewModel(book: book, variant: variant)
        #expect(vm.currentParagraph == 2)   // clamped to last index
    }
}
