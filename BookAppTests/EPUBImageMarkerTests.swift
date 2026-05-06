import Testing
@testable import BookApp

/// Inline-image extraction was added in v10. These tests pin down the
/// invariants the rest of the reader and TTS depend on:
///   1. <img> tags become standalone `[img:filename]` paragraphs.
///   2. The basename, not the full path, is what survives.
///   3. The merge-fragmented-paragraphs pass keeps image markers as
///      their own paragraph rather than gluing them to surrounding text.
struct EPUBImageMarkerTests {

    @Test
    func imageTagBecomesStandaloneMarker() {
        let html = """
        <p>Some prose before.</p>
        <p><img src="figure-3.png" alt="Figure 3"/></p>
        <p>And prose after.</p>
        """
        let plain = EPUBParser.htmlToPlainText(html)
        #expect(plain.contains("[img:figure-3.png]"))
        // The marker should be its own paragraph (separated by blank lines)
        // not appended to surrounding prose.
        let paragraphs = plain.components(separatedBy: "\n\n")
        #expect(paragraphs.contains(where: { $0.trimmingCharacters(in: .whitespaces) == "[img:figure-3.png]" }))
    }

    @Test
    func srcWithSubdirectoryIsPreservedVerbatim() {
        // We pass through the href as-is; the consumer (ReaderView) is
        // responsible for taking the lastPathComponent. The reader then
        // looks the file up in <bookFolder>/images/ which is flat.
        let html = #"<img src="../images/figure.jpg" />"#
        let plain = EPUBParser.htmlToPlainText(html)
        #expect(plain.contains("[img:../images/figure.jpg]"))
    }

    @Test
    func imageMarkerSurvivesFragmentedParagraphMerge() {
        // The merge pass joins paragraphs whose first doesn't end with
        // sentence-terminating punctuation. Image markers must be exempt
        // — otherwise figures get glued onto whatever caption preceded
        // them, breaking the reader's image-block detection.
        let html = """
        <p>Setup sentence without period</p>
        <p><img src="diagram.png"/></p>
        <p>Following sentence.</p>
        """
        let plain = EPUBParser.htmlToPlainText(html)
        let paragraphs = plain.components(separatedBy: "\n\n").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        #expect(paragraphs.contains("[img:diagram.png]"))
    }
}
