import XCTest
@testable import ScrollShotCore
final class IdleStopTests: XCTestCase {
    func testDoesNotStopBeforeFirstActualScroll() {
        var detector = IdleStopDetector(preferences: CapturePreferences(idleSeconds: 1))
        detector.observe(.stationary,at: 0);detector.observe(.uncertain,at: 4)
        XCTAssertFalse(detector.poll(at: 100))
    }
    func testFractionalTimeoutStartsAtLastScrollAndFiresOnce() {
        var detector = IdleStopDetector(preferences: CapturePreferences(idleSeconds: 2.5))
        detector.observe(.scrolling,at: 10);detector.observe(.stationary,at: 11)
        XCTAssertFalse(detector.poll(at: 12.49));XCTAssertTrue(detector.poll(at: 12.5));XCTAssertFalse(detector.poll(at: 100))
    }
    func testRenewedScrollAndUncertainChangesPostponeExpiry() {
        var detector = IdleStopDetector(preferences: CapturePreferences(idleSeconds: 3))
        detector.observe(.scrolling,at: 1);detector.observe(.scrolling,at: 3);detector.observe(.uncertain,at: 5)
        XCTAssertFalse(detector.poll(at: 7.9));XCTAssertTrue(detector.poll(at: 8))
    }
    func testDisabledAndResetDoNotStop() {
        var off = IdleStopDetector(preferences: CapturePreferences(idleStopEnabled: false,idleSeconds: 0.1))
        off.observe(.scrolling,at: 1);XCTAssertFalse(off.poll(at: 100))
        var detector = IdleStopDetector(preferences: CapturePreferences(idleSeconds: 1))
        detector.observe(.scrolling,at: 1);detector.reset();XCTAssertFalse(detector.poll(at: 100))
        detector.observe(.scrolling,at: 101);XCTAssertTrue(detector.poll(at: 102))
    }
    func testInvalidAndBackwardClockValuesCannotTriggerOrRewind() {
        var detector = IdleStopDetector(preferences: CapturePreferences(idleSeconds: 1))
        detector.observe(.scrolling,at: 10);detector.observe(.uncertain,at: 4)
        XCTAssertFalse(detector.poll(at: .infinity));XCTAssertFalse(detector.poll(at: .nan));XCTAssertFalse(detector.poll(at: 9))
        XCTAssertTrue(detector.poll(at: 11))
    }
    func testLargeCustomTimeoutIsNotLimitedToPresetValues() {
        var detector = IdleStopDetector(preferences: CapturePreferences(idleSeconds: 7200.25))
        detector.observe(.scrolling,at: 0);XCTAssertFalse(detector.poll(at: 7200));XCTAssertTrue(detector.poll(at: 7200.25))
    }
}
