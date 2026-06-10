import XCTest

/// End-to-end smoke for the Listen-mode pause/resume cycle. Exists to
/// catch the v21 regression: tap pause then tap play immediately
/// re-paused the synth because iOS posted a spurious audio-session
/// `.began` interruption in immediate response to the user action.
///
/// The test launches with `-uitesting` so onboarding is skipped, opens
/// the first book on the shelf, switches to Listen mode, and asserts the
/// play/pause toggle behaves like a normal media player.
///
/// @MainActor because Xcode 16.4's XCTest annotates the XCUI APIs as
/// main-actor-isolated; under strict concurrency a nonisolated test
/// class no longer compiles against them.
@MainActor
final class ReaderListenFlowTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testListenPauseResumeStaysResumed() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitesting"]
        app.launch()

        // Library renders the seeded books once SeedBooksLoader finishes.
        // First launch on a fresh simulator can take ~3s while seeds copy
        // into the SwiftData store.
        let firstBookCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "by"))
            .firstMatch
        XCTAssert(firstBookCard.waitForExistence(timeout: 8),
                  "Library failed to render any seeded books")
        firstBookCard.tap()

        // Mode pill — labelled "Listen mode" by the a11y pass.
        let listenTab = app.buttons["Listen mode"]
        XCTAssert(listenTab.waitForExistence(timeout: 4),
                  "Reader didn't render the mode pill")
        listenTab.tap()

        // The play button starts in "Pause narration" state because
        // entering Listen kicks off playback automatically.
        let pauseButton = app.buttons["Pause narration"]
        XCTAssert(pauseButton.waitForExistence(timeout: 4),
                  "Listen mode didn't begin narration on entry")
        pauseButton.tap()

        // After tap, label should flip to "Resume narration".
        let resumeButton = app.buttons["Resume narration"]
        XCTAssert(resumeButton.waitForExistence(timeout: 2),
                  "Pause didn't flip the label to Resume")
        resumeButton.tap()

        // Regression: after tapping Resume, the pause label should
        // appear AND stay for at least 2 seconds. The v21 bug was that
        // a spurious `.began` interruption immediately re-paused, so
        // the Pause label would disappear within ~100ms.
        let pauseAgain = app.buttons["Pause narration"]
        XCTAssert(pauseAgain.waitForExistence(timeout: 1),
                  "Resume didn't flip the label back to Pause")
        let stillPausing = pauseAgain.waitForExistence(timeout: 2.5)
        XCTAssert(stillPausing,
                  "Resume immediately re-paused — interruption suppression regressed")
    }
}
