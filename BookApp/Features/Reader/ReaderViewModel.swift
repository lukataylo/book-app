import Foundation
import Observation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

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
        // .speedReader is no longer used — Speed mode is inline now.
        case readerSettings, ttsSettings, transformations, chapters, search, markings
        var id: String { String(describing: self) }
    }

    /// Pre-computed chapter index for the current variant. Driven by `# Heading`
    /// markers in `contentText`; works identically for the original EPUB and
    /// any AI-transformed variant since both keep heading lines.
    var chapters: [ChapterMark] {
        var marks: [ChapterMark] = []
        for (idx, p) in paragraphs.enumerated() where p.hasPrefix("# ") {
            let title = String(p.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            marks.append(ChapterMark(title: title, paragraphIndex: idx))
        }
        return marks
    }

    struct ChapterMark: Hashable {
        let title: String
        let paragraphIndex: Int
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
        publishWidgetSnapshot(percent: percent)
    }

    /// Push the latest progress + cover into the App Group container so the
    /// home-screen widget can render it without launching the app. Best
    /// effort — failures here are silent because the widget is decoration,
    /// not a load-bearing feature.
    private func publishWidgetSnapshot(percent: Double) {
        var coverFilename = ""
        if let coverData = book.coverData {
            let leaf = "\(book.id.uuidString).jpg"
            if let target = WidgetSnapshot.coverURL(filename: leaf) {
                try? coverData.write(to: target, options: .atomic)
                coverFilename = leaf
            }
        }
        let snap = WidgetSnapshot(
            bookID: book.id.uuidString,
            title: book.title,
            author: book.author,
            percent: percent,
            coverFilename: coverFilename,
            updatedAt: .now
        )
        snap.write()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
