import XCTest

/// Settings → Reset all content, then relaunch, and the catalog has to
/// come back.
///
/// This shipped broken: reset cleared a hardcoded `-v2` copy of the
/// loader's re-seed key while the loader read `-v4`, so a reset deleted
/// every book *and* left the guard in place. The library was then empty
/// forever, on a device the user could only recover by deleting the app —
/// and "reset all content" is exactly the button an App Review tester
/// looking for a data-deletion path presses.
///
/// A unit test pins the key. Only a relaunch proves the catalog returns,
/// which is why this one lives here.
@MainActor
final class ResetAndReseedTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// The catalog seeds asynchronously on launch, so both the initial
    /// check and the post-reset one need a generous window.
    private func waitForCatalog(_ app: XCUIApplication, _ message: String) {
        let searchField = app.textFields.firstMatch
        XCTAssert(searchField.waitForExistence(timeout: 20), "\(message): no search field")
        searchField.tap()
        searchField.typeText("Meditations")
        let card = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Meditations")
        ).firstMatch
        XCTAssert(card.waitForExistence(timeout: 30), message)

        // Leave the Library as we found it. The keyboard raised by the
        // search field otherwise sits over the tab bar, and the tab
        // switch below silently taps the keyboard instead.
        app.buttons["Clear search"].tap()
        if app.keyboards.element.exists {
            app.typeText("\n")
        }
    }

    func testResetAllContentRestoresTheCatalogOnNextLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitesting"]
        app.launch()

        waitForCatalog(app, "catalog never seeded on first launch")

        // Settings → Reset all content → confirm.
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssert(settingsTab.waitForExistence(timeout: 6), "no Settings tab")
        settingsTab.tap()

        // Reset lives near the bottom of a long Form; scroll it into view
        // rather than assuming it starts on screen.
        let reset = app.buttons["Reset all content"]
        var swipes = 0
        while !reset.exists, swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssert(reset.waitForExistence(timeout: 6), "Settings didn't render the reset control")
        reset.tap()

        // The confirmation is a destructive alert; its button carries the
        // same title as the row that opened it.
        let confirm = app.alerts.buttons["Reset"]
        XCTAssert(confirm.waitForExistence(timeout: 6), "reset didn't ask for confirmation")
        confirm.tap()

        // The copy promises the starter library reloads next launch, so
        // relaunching is the actual contract under test.
        app.terminate()
        app.launch()

        waitForCatalog(app, "catalog did not come back after a reset — the app is empty forever")
    }
}
