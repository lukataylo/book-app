import Testing
import Foundation
@testable import BookApp

/// Pinned regressions for the TTS state machine. The bugs being fixed
/// here have been re-introduced more than once in v15-v20; these tests
/// exist to make sure the next one trips CI instead of the user.
@MainActor
struct TTSEngineTests {

    // MARK: - cleanParagraphs

    @Test
    func cleanParagraphsStripsHeadingMarkers() {
        let raw = ["# Chapter One", "First paragraph.", "# Chapter Two", "Second paragraph."]
        let result = TTSEngine.cleanParagraphs(raw)
        #expect(result.cleaned == ["Chapter One", "First paragraph.", "Chapter Two", "Second paragraph."])
        // Source mapping preserves original positions so the reader can
        // highlight the right block in the body.
        #expect(result.sources == [0, 1, 2, 3])
    }

    @Test
    func cleanParagraphsDropsEmptiesAndImages() {
        let raw = [
            "First.",
            "",
            "   ",
            "[img:figure-1.jpg]",
            "Second.",
            "[img:nested/path/figure-2.png]",
            "Third."
        ]
        let result = TTSEngine.cleanParagraphs(raw)
        #expect(result.cleaned == ["First.", "Second.", "Third."])
        // Engine-index → block-index mapping skips the blanks and images.
        // This is the invariant currentSourceParagraph relies on for
        // listen-mode auto-scroll to land on the right paragraph.
        #expect(result.sources == [0, 4, 6])
    }

    @Test
    func cleanParagraphsHandlesAllEmptyInput() {
        let result = TTSEngine.cleanParagraphs(["", "  ", "[img:x]"])
        #expect(result.cleaned.isEmpty)
        #expect(result.sources.isEmpty)
    }

    @Test
    func stripHeadingMarkerLeavesBodyAlone() {
        #expect(TTSEngine.stripHeadingMarker("# Foo") == "Foo")
        #expect(TTSEngine.stripHeadingMarker("Foo") == "Foo")
        // Only strips the marker form `# ` — a literal "#hashtag" is body.
        #expect(TTSEngine.stripHeadingMarker("#hashtag") == "#hashtag")
    }

    // MARK: - Interruption suppression window
    //
    // Regression for the v21 fix: tap pause then tap play immediately
    // re-paused the synth. iOS posts a spurious `.began` interruption
    // in immediate response to our own pauseSpeaking / setActive calls;
    // we suppress those by checking the time since the last in-app
    // pause/resume.

    @Test
    func interruptionSuppressionIgnoresActionsWithinWindow() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let recentlyTapped = now.addingTimeInterval(-0.2)
        #expect(TTSEngine.shouldSuppressInterruption(
            lastUserAction: recentlyTapped, now: now, window: 0.6
        ))
    }

    @Test
    func interruptionSuppressionPassesThroughOldActions() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let agesAgo = now.addingTimeInterval(-5)
        #expect(!TTSEngine.shouldSuppressInterruption(
            lastUserAction: agesAgo, now: now, window: 0.6
        ))
    }

    @Test
    func interruptionSuppressionPassesThroughWhenNoActionRecorded() {
        // Cold engine: a real interruption (phone call) right at launch
        // should still pause us.
        #expect(!TTSEngine.shouldSuppressInterruption(
            lastUserAction: nil, now: Date(), window: 0.6
        ))
    }

    @Test
    func interruptionSuppressionExpiresAtWindowBoundary() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let exactlyAtBoundary = now.addingTimeInterval(-0.6)
        // < (strict) means a sample exactly at the window edge passes
        // through. Conservative — we'd rather forward a real
        // interruption than swallow one.
        #expect(!TTSEngine.shouldSuppressInterruption(
            lastUserAction: exactlyAtBoundary, now: now, window: 0.6
        ))
    }

    // MARK: - Pause / resume state

    @Test
    func pauseFlipsPlayingFlagAndRecordsAction() {
        let engine = TTSEngine()
        engine.isPlaying = true
        engine.pause()
        #expect(engine.isPlaying == false)
        // pause() must record the timestamp so the interruption guard
        // works on the very next runloop tick.
        #expect(TTSEngine.shouldSuppressInterruption(
            lastUserAction: engine.lastUserActionForTesting,
            now: .now,
            window: 0.6
        ))
    }

    @Test
    func resumeFlipsPlayingFlagAndRecordsAction() {
        let engine = TTSEngine()
        engine.isPlaying = false
        engine.resume()
        // resume() optimistically marks isPlaying = true; an immediate
        // spurious `.began` from iOS would otherwise re-pause us.
        #expect(engine.isPlaying == true)
        #expect(TTSEngine.shouldSuppressInterruption(
            lastUserAction: engine.lastUserActionForTesting,
            now: .now,
            window: 0.6
        ))
    }

    // MARK: - Loaded-content book identity

    @Test
    func isLoadedForReturnsFalseOnFreshEngine() {
        let engine = TTSEngine()
        let book = UUID()
        let variant = UUID()
        #expect(engine.isLoadedFor(bookID: book, variantID: variant) == false)
    }

    @Test
    func currentSourceParagraphIsNilWhenNothingLoaded() {
        let engine = TTSEngine()
        #expect(engine.currentSourceParagraph == nil)
    }
}
