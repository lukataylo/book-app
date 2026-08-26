import Testing
import Foundation
@testable import BookApp

/// The book page's blurb had its own paragraph splitter, which split on
/// blank lines only. Project Gutenberg hard-wraps at ~70 columns, so a
/// paragraph arrives carrying lone newlines *inside* it — and SwiftUI
/// renders those as visible breaks, giving a blurb that snaps
/// mid-sentence while the very same text flowed correctly in the reader.
@MainActor
struct BlurbTests {

    /// Shaped like a real Gutenberg paragraph: one logical paragraph
    /// wrapped across several physical lines.
    private let hardWrapped = """
    Nicolo Machiavelli, born at Florence on 3rd May 1469. From 1494 to 1512
    held an official post at Florence which included diplomatic missions to
    various European courts.

    Nicolo Machiavelli was born at Florence on 3rd May 1469. He was the second
    son of Bernardo di Nicolo Machiavelli, a lawyer of some repute.
    """

    @Test
    func blurbUnwrapsHardWrappedParagraphs() {
        let blurb = BookDetailView.openingParagraphs(of: hardWrapped)
        // The wrap points must be gone…
        #expect(!blurb.contains("From 1494 to 1512\nheld"))
        #expect(blurb.contains("From 1494 to 1512 held"))
        // …while the real paragraph break survives.
        #expect(blurb.components(separatedBy: "\n\n").count == 2)
    }

    /// `limit` is what keeps the blurb to a glance rather than the whole
    /// first chapter.
    ///
    /// Each paragraph has to clear `mergeFragments`' 40-character floor —
    /// below it, a block is assumed to be a wrap fragment and joined to
    /// the next, which is what repairs one-line-per-paragraph Gutenberg
    /// HTML. A fixture of short lines tests the merge, not the limit.
    @Test
    func blurbStopsAtTheLimit() {
        let three = [
            "The first paragraph runs long enough to stand on its own.",
            "The second paragraph likewise clears the fragment floor.",
            "The third paragraph should never reach a two-item blurb.",
        ].joined(separator: "\n\n")
        let blurb = BookDetailView.openingParagraphs(of: three, limit: 2)
        #expect(blurb.components(separatedBy: "\n\n").count == 2)
        #expect(!blurb.contains("third"))
    }

    /// A catalog title opens with a `# ` heading and imported EPUBs can
    /// open with a figure; neither is a blurb.
    @Test
    func blurbSkipsHeadingsAndImages() {
        let text = "# CHAPTER I\n\n[img:plate1.jpg]\n\nThe actual opening sentence of the book."
        let blurb = BookDetailView.openingParagraphs(of: text)
        #expect(blurb == "The actual opening sentence of the book.")
    }

    /// The bundled works are the texts this actually runs against, so
    /// assert against one rather than only a synthetic fixture.
    @Test
    func aBundledWorkProducesAFlowingBlurb() throws {
        let source = try #require(SummaryPackLoader.fullText(for: "the-prince"))
        let blurb = BookDetailView.openingParagraphs(of: source)
        #expect(!blurb.isEmpty)
        // No paragraph in a blurb should carry an interior newline.
        for paragraph in blurb.components(separatedBy: "\n\n") {
            #expect(!paragraph.contains("\n"), "interior break in: \(paragraph.prefix(60))")
        }
    }
}
