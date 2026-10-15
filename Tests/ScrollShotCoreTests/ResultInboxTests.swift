import XCTest
@testable import ScrollShotCore
final class ResultInboxTests: XCTestCase {
    func testNewestCompletedResultIsSelectedOnce() throws {
        let older = session(at: 1),newer = session(at: 2)
        XCTAssertEqual(ResultInbox.next(in: [older,newer],after: .distantPast)?.id,newer.id)
        XCTAssertNil(ResultInbox.next(in: [newer,older],after: newer.createdAt))
    }
    func testExistingExportCanAutoOpenWithoutReexporting() {
        var completed = session(at: 3);completed.outputs = ["result.png"]
        XCTAssertEqual(ResultInbox.next(in: [completed],after: Date(timeIntervalSince1970: 2))?.id,completed.id)
    }
    func testActiveOrFailedLatestSessionDoesNotShowAnOlderUnseenImage() {
        let older = session(at: 1)
        for state in [SessionState.recording,.paused,.interrupted,.failed] {
            var latest = session(at: 2);latest.state = state
            XCTAssertNil(ResultInbox.next(in: [older,latest],after: .distantPast))
        }
        var empty = session(at: 3);empty.frames = []
        XCTAssertNil(ResultInbox.next(in: [older,empty],after: .distantPast))
    }
    private func session(at time: Double) -> SessionManifest {
        var s = SessionManifest();s.createdAt = Date(timeIntervalSince1970: time);s.state = .ready
        s.frames = [FrameRecord(fileName: "a.jpg",width: 80,height: 400,offsetY: 0,timestamp: 0)];return s
    }
}
