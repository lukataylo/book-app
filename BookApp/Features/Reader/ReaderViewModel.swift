import Foundation
import Observation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// One renderable item in the reader's scrolling stack — derived from a
/// single source paragraph. Pre-classified so the view doesn't have to
/// re-scan prefix markers (`# `, `[img:`) on every body re-render.
enum ReaderBlock: Hashable {
    case heading(String)
    case paragraph(String)
    case image(String)   // filename, resolved against the book's images/ folder
}

/// A `ReaderBlock` plus the cross-paragraph context the view needs to render
/// it (currently just whether this paragraph is the first after a heading,
/// for drop-cap rendering).
struct RenderableBlock: Hashable {
    let block: ReaderBlock
    let firstAfterHeading: Bool
}

/// Owns reader state for a single book — current variant, progress, paragraph
/// list (used by speed reader + TTS), and the navigation hooks the bottom bar
/// triggers (Read / Listen / Settings / AI).
@Observable
@MainActor
final class ReaderViewModel {
    let book: Book
    var currentVariant: BookVariant
    var paragraphs: [String] = []
    /// Pre-classified renderable blocks for the current variant. Cached
    /// because the reader's body re-renders on every settings tick (font
    /// size, line spacing, theme…) and an O(n) scan over paragraphs each
    /// time was the dominant cost when adjusting type with a long book
    /// loaded.
    var blocks: [RenderableBlock] = []
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
        self.blocks = Self.buildBlocks(from: paragraphs)
        self.currentParagraph = Self.resumeParagraphIndex(
            book: book,
            variantID: currentVariant.id,
            paragraphCount: paragraphs.count
        )
    }

    /// Look up the most recent saved progress for this book + variant and
    /// translate it into a paragraph index. Locator format `para:<n>` is
    /// the canonical form (precise resume); legacy `scroll:<percent*1e6>`
    /// values fall back to a percent-of-paragraphs estimate.
    private static func resumeParagraphIndex(book: Book, variantID: UUID, paragraphCount: Int) -> Int {
        guard paragraphCount > 0 else { return 0 }
        let progress = (book.progress ?? [])
            .filter { $0.variantID == variantID }
            .max { $0.updatedAt < $1.updatedAt }
        guard let progress else { return 0 }
        let locator = progress.locator
        if locator.hasPrefix("para:"),
           let n = Int(locator.dropFirst(5)) {
            return max(0, min(n, paragraphCount - 1))
        }
        if locator.hasPrefix("scroll:") {
            let est = Int(progress.percent * Double(paragraphCount))
            return max(0, min(est, paragraphCount - 1))
        }
        return 0
    }

    static func splitParagraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Classify each paragraph string into a `ReaderBlock` and tag the first
    /// paragraph after a heading so the view can render a drop cap there.
    static func buildBlocks(from paragraphs: [String]) -> [RenderableBlock] {
        var result: [RenderableBlock] = []
        result.reserveCapacity(paragraphs.count)
        var prevWasHeading = false
        for p in paragraphs {
            if p.hasPrefix("# ") {
                let title = String(p.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                result.append(RenderableBlock(block: .heading(title), firstAfterHeading: false))
                prevWasHeading = true
            } else if p.hasPrefix("[img:"), p.hasSuffix("]") {
                let inner = String(p.dropFirst(5).dropLast())
                let leaf = (inner as NSString).lastPathComponent
                result.append(RenderableBlock(block: .image(leaf), firstAfterHeading: false))
                prevWasHeading = false
            } else {
                result.append(RenderableBlock(block: .paragraph(p), firstAfterHeading: prevWasHeading))
                prevWasHeading = false
            }
        }
        return result
    }

    func switchVariant(_ variant: BookVariant) {
        currentVariant = variant
        paragraphs = Self.splitParagraphs(variant.contentText)
        blocks = Self.buildBlocks(from: paragraphs)
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
