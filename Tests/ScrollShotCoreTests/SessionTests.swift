import XCTest
@testable import ScrollShotCore
final class SessionTests: XCTestCase {
    func testAtomicRoundTripAndIndependentSessions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { if FileManager.default.fileExists(atPath: root.path) { try? FileManager.default.removeItem(at: root) } }
        let store = try SessionStore(root: root)
        var a = try store.create(); let b = try store.create()
        a.frames = [FrameRecord(fileName: "0.jpg",width: 40,height: 100,offsetY: 0,timestamp: 0)]
        try store.writeFrame(Data([1,2,3]),fileName: "0.jpg",session: a.id)
        a.state = .interrupted; try store.save(a)
        let loaded = try SessionStore(root: root).load(a.id)
        XCTAssertEqual(loaded.frames,a.frames)
        XCTAssertEqual(loaded.state,.interrupted)
        XCTAssertEqual(try store.load(b.id).frames.count,0)
        XCTAssertEqual(try store.all().count,2)
        XCTAssertEqual(try Data(contentsOf: store.directory(for: a.id).appendingPathComponent("0.jpg")),Data([1,2,3]))
    }
    func testFramePathCannotEscapeSession() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { if FileManager.default.fileExists(atPath: root.path) { try? FileManager.default.removeItem(at: root) } }
        let store = try SessionStore(root: root); let session = try store.create()
        XCTAssertThrowsError(try store.writeFrame(Data([1]),fileName: "../outside",session: session.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("outside").path))
    }
}
