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
    /// True while the reader is waiting on the variant's body text to
    /// arrive from disk. New imports / migrated rows store the body in
    /// `<bookFolder>/variant-<id>.txt`; init populates as much as it
    /// can from the legacy in-row `contentText`, then `load()` finishes
    /// the job asynchronously.
    var isLoading: Bool = false

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
        // Best-effort sync init: legacy / test rows still carry the
        // body text in-row. If the row has been migrated (or freshly
        // imported via the disk-backed path) `contentText` is empty
        // and we'll populate paragraphs in `load()`.
        let inMemory = currentVariant.contentText
        self.paragraphs = Self.splitParagraphs(inMemory)
        self.blocks = Self.buildBlocks(from: paragraphs)
        self.currentParagraph = Self.resumeParagraphIndex(
            book: book,
            variantID: currentVariant.id,
            paragraphCount: paragraphs.count
        )
        // We're loading iff paragraphs are still empty — that means
        // either contentText was blank (migrated / freshly imported row,
        // body lives on disk) or the variant genuinely has no content.
        // Either way `load()` figures it out.
        self.isLoading = paragraphs.isEmpty
    }

    /// Async second-stage load. Pulls the body from disk
    /// (`BookVariant.loadText()`) when the in-row `contentText` was
    /// empty, then re-runs paragraph splitting + resume resolution.
    /// Idempotent — safe to call from the reader's `.task`, no-op when
    /// the sync init already populated paragraphs.
    func load() async {
        guard isLoading else { return }
        let text = await currentVariant.loadText()
        guard !text.isEmpty else {
            isLoading = false
            return
        }
        let split = Self.splitParagraphs(text)
        self.paragraphs = split
        self.blocks = Self.buildBlocks(from: split)
        self.currentParagraph = Self.resumeParagraphIndex(
            book: book,
            variantID: currentVariant.id,
            paragraphCount: split.count
        )
        self.isLoading = false
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
        // Defensive normalisation: stored `contentText` from older parser
        // versions can contain in-paragraph `\r` / lone `\n` (from
        // Project-Gutenberg-style hard-wrapped HTML) which SwiftUI's `Text`
        // renders as visible hard breaks, plus `\n\n` fragmentation
        // (whole-paragraph-per-visual-line). We can't re-import without
        // dropping the user's annotations + progress on the seed books,
        // so the fix runs at read time.
        var normalised = text
        normalised = normalised.replacingOccurrences(of: "\r\n", with: "\n")
        normalised = normalised.replacingOccurrences(of: "\r", with: "\n")
        // Lone newline (not surrounded by another newline) → space, so
        // a paragraph hard-wrapped over many physical lines flows back
        // into one. `\n\n` paragraph boundaries survive because their
        // newlines flank each other.
        normalised = normalised.replacingOccurrences(
            of: "(?<!\\n)\\n(?!\\n)",
            with: " ",
            options: .regularExpression
        )
        let parts = normalised.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return mergeFragments(parts)
    }

    /// Join consecutive paragraphs that don't end with sentence-terminating
    /// punctuation — same heuristic the EPUB parser uses to repair
    /// Project-Gutenberg-style one-line-per-paragraph HTML, applied at read
    /// time so books imported before the parser had this step still flow.
    private static func mergeFragments(_ parts: [String]) -> [String] {
        guard parts.count > 1 else { return parts }
        let terminals: Set<Character> = [".", "!", "?", ":", "”", "\"", "…", "’", "'", ")"]
        var out: [String] = []
        out.reserveCapacity(parts.count)
        var buffer = ""
        for part in parts {
            // Headings + image markers are paragraph-final on their own
            // regardless of trailing punctuation — keep them isolated so
            // the reader's heading style + inline image rendering still
            // pick them up.
            let isHeading = part.hasPrefix("# ")
            let isImage = part.hasPrefix("[img:") && part.hasSuffix("]")
            if isHeading || isImage {
                if !buffer.isEmpty { out.append(buffer); buffer = "" }
                out.append(part)
                continue
            }
            buffer = buffer.isEmpty ? part : "\(buffer) \(part)"
            if let last = part.last, terminals.contains(last), buffer.count > 40 {
                out.append(buffer)
                buffer = ""
            }
        }
        if !buffer.isEmpty { out.append(buffer) }
        return out
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

    func switchVariant(_ variant: BookVariant) async {
        currentVariant = variant
        let text = await variant.loadText()
        let split = Self.splitParagraphs(text)
        self.paragraphs = split
        self.blocks = Self.buildBlocks(from: split)
        self.currentParagraph = 0
        self.isLoading = false
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
        // `coverImageData()` resolves both the legacy in-row data and
        // the new disk-backed file, so the widget snapshot keeps
        // working through the migration.
        if let coverData = book.coverImageData() {
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
