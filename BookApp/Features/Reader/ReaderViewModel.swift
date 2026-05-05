import Foundation
import Observation
import SwiftData

/// Owns reader state for a single book — current variant, progress, paragraph
/// list (used by speed reader + TTS), and the navigation hooks the bottom bar
/// triggers (Read / Listen / Settings / AI).
@Observable
@MainActor
final class ReaderViewModel {
    let book: Book
    var currentVariant: BookVariant
    var paragraphs: [String] = []
    var currentParagraph: Int = 0
    var sheet: Sheet?

    enum Sheet: Identifiable {
        case readerSettings, ttsSettings, speedReader, transformations, learnings
        var id: String { String(describing: self) }
    }

    init(book: Book, variant: BookVariant? = nil) {
        self.book = book
        self.currentVariant = variant ?? book.originalVariant ?? BookVariant(book: book, kind: .original, contentText: "")
        self.paragraphs = Self.splitParagraphs(currentVariant.contentText)
    }

    static func splitParagraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func switchVariant(_ variant: BookVariant) {
        currentVariant = variant
        paragraphs = Self.splitParagraphs(variant.contentText)
        currentParagraph = 0
    }

    func updateProgress(percent: Double, locator: String, in context: ModelContext) {
        let bookID = book.id
        let variantID = currentVariant.id
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.book?.id == bookID && $0.variantID == variantID }
        )
        let existing = (try? context.fetch(descriptor))?.first
        if let existing {
            existing.percent = percent
            existing.locator = locator
            existing.updatedAt = .now
        } else {
            let p = ReadingProgress(book: book, variantID: variantID, locator: locator, percent: percent)
            context.insert(p)
        }
        book.lastOpenedAt = .now
        try? context.save()
    }
}
