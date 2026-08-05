import XCTest

/// Captures the App Store screenshot set. Not a correctness test — run it
/// with `-only-testing:BookAppUITests/StoreShotTests` when the listing
/// needs regenerating, and pull the PNGs out of the app's tmp directory.
@MainActor
final class StoreShotTests: XCTestCase {
    func testCaptureStoreShots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitesting"]
        app.launch()

        let search = app.textFields.firstMatch
        XCTAssert(search.waitForExistence(timeout: 25))
        sleep(4)
        shot("library")

        search.tap()
        search.typeText("Art of War")
        sleep(3)
        let card = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Art of War")).firstMatch
        XCTAssert(card.waitForExistence(timeout: 10))
        card.tap(); sleep(4)
        shot("detail")

        let read = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "reading")).firstMatch
        if read.waitForExistence(timeout: 8) {
            read.tap(); sleep(6)
            shot("reader")
        }
    }

    private func shot(_ name: String) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("store-\(name).png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        print("SHOT \(url.path)")
    }
}
