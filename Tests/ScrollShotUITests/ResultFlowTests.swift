import XCTest
final class ResultFlowTests: XCTestCase {
    @MainActor func testLibrarySettingsAndImageTools() throws {
        let app=XCUIApplication();app.launch()
        if app.buttons["result.close"].waitForExistence(timeout:2) {app.buttons["result.close"].tap()}
        let settings=app.buttons["home.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout:5));settings.tap()
        XCTAssertTrue(app.segmentedControls["settings.appearance"].waitForExistence(timeout:5))
        XCTAssertTrue(app.textFields["settings.compression.mb"].exists)
        app.buttons["settings.done"].tap()
        app.buttons.matching(identifier:"library.open").firstMatch.tap()
        app.buttons["result.tools"].tap()
        XCTAssertTrue(app.buttons["tools.image"].waitForExistence(timeout:5));app.buttons["tools.image"].tap()
        XCTAssertTrue(app.segmentedControls["image.mode"].waitForExistence(timeout:5))
        app.buttons["image.cancel"].tap()
    }
    @MainActor func testFreshResultOpensFullscreenSavesAndDoesNotReopenAfterDismissal() throws {
        let app = XCUIApplication();app.launch()
        let save = app.buttons["result.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 20),"A fresh ready draft must automatically open the fullscreen viewer")
        XCTAssertTrue(app.scrollViews["result.preview"].waitForExistence(timeout: 20))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"),object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled],timeout: 20),.completed)
        XCTAssertTrue(save.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot());screenshot.lifetime = .keepAlways;add(screenshot)
        save.tap()
        XCTAssertTrue(app.staticTexts["result.saved"].waitForExistence(timeout: 15),"The floating button must complete a real Photos addition")
        app.buttons["result.close"].tap()
        XCTAssertTrue(app.buttons["home.import.files"].waitForExistence(timeout: 5))
        app.terminate();app.launch()
        XCTAssertTrue(app.buttons["home.import.files"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["result.save"].exists,"A dismissed old result must not reopen on app relaunch")
    }
}
