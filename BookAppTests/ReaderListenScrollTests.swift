import Testing
import SwiftUI
@testable import BookApp

/// Regression for the listen-mode follow-scroll cursor-under-bar bug:
/// when the engine advanced to the next paragraph, the previous code
/// scrolled with `anchor: .center`, parking long paragraphs so that
/// the per-word highlight cursor ended up in the faded/icon-covered
/// bottom strip. The fix anchors at the top of the viewport.
struct ReaderListenScrollTests {

    @Test
    func listenAnchorIsTopNotCenter() {
        #expect(ReaderMode.listenScrollAnchor == .top)
        // .center was the historical value; this assert documents
        // the deliberate divergence so a future "round-trip the
        // anchor through settings" refactor can't quietly revert.
        #expect(ReaderMode.listenScrollAnchor != .center)
    }
}
