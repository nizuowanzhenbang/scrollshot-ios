import XCTest
final class ResultFlowTests: XCTestCase {
    @MainActor func testLibrarySettingsAndImageTools() throws {
        let app=XCUIApplication();app.launch()
        if app.buttons["result.close"].waitForExistence(timeout:2) {app.buttons["result.close"].tap()}
        let settings=app.buttons["home.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout:5));settings.tap()
        XCTAssertTrue(app.segmentedControls["settings.appearance"].waitForExistence(timeout:5))
        XCTAssertTrue(app.textFields["settings.compression.mb"].exists)
        let field=app.textFields["settings.compression.mb"];field.tap()
        let count=(field.value as? String)?.count ?? 4
        field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:count)+"0.0001")
        app.buttons["settings.compression.save"].tap()
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.buttons["library.more"].waitForExistence(timeout:5))
        app.buttons["library.more"].tap()
        let rows=app.buttons.matching(identifier:"library.open")
        XCTAssertGreaterThan(rows.count,5)
        let last=rows.element(boundBy:rows.count-1)
        if !last.isHittable {app.swipeUp()}
        last.swipeRight()
        XCTAssertTrue(app.buttons["library.delete"].waitForExistence(timeout:5));app.buttons["library.delete"].tap()
        app.buttons["library.confirm.delete"].tap()
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons.matching(identifier:"library.open").firstMatch.tap()
        app.buttons["result.save"].tap()
        XCTAssertTrue(app.buttons["保存原始 PNG"].waitForExistence(timeout:5))
        app.buttons["取消"].tap()
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
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 5))
        app.terminate();app.launch()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["result.save"].exists,"A dismissed old result must not reopen on app relaunch")
    }
}
