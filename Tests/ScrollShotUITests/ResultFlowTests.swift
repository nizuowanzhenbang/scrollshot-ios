import XCTest
final class ResultFlowTests: XCTestCase {
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
