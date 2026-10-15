import XCTest
import CoreImage
import CoreGraphics
@testable import ScrollShotCore
final class RecordingSessionTests: XCTestCase {
    func testWatchdogFinishesTailWithoutAnyFurtherVideoCallbacks() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at: root)}
        let store = try SessionStore(root: root),stopped = expectation(description: "idle callback")
        stopped.assertForOverFulfill = true
        let session = try RecordingSession(store: store,preferences: CapturePreferences(idleSeconds: 0.1)) { reason in
            if case .idle = reason {stopped.fulfill()}
        }
        let source = fixture(width: 80,height: 500)
        try session.process(image: image(source,start: 0),timestamp: 0)
        try session.process(image: image(source,start: 10),timestamp: 0.25)
        await fulfillment(of: [stopped],timeout: 3)
        let result = try store.load(session.id)
        XCTAssertEqual(result.state,.ready);XCTAssertEqual(result.finishReason,.idle)
        XCTAssertEqual(result.frames.last?.offsetY,10)
        try session.finish()
        XCTAssertEqual(try store.load(session.id).finishReason,.idle,"Late ReplayKit finish must not overwrite idle completion")
    }
    func testStaticStartAndPausedCaptureCannotAutoStop() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at: root)}
        let stopped = expectation(description: "no early finish");stopped.isInverted = true
        let store = try SessionStore(root: root),session = try RecordingSession(store: store,preferences: CapturePreferences(idleSeconds: 0.05)) {_ in stopped.fulfill()}
        let source = fixture(width: 80,height: 500)
        try session.process(image: image(source,start: 0),timestamp: 0)
        await fulfillment(of: [stopped],timeout: 0.2)
        try session.process(image: image(source,start: 10),timestamp: 0.25);try session.pause()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(try store.load(session.id).state,.paused)
        try session.finish(state: .interrupted,reason: .failed)
    }
    private func image(_ source: [UInt8],start: Int) -> CIImage {
        let provider = CGDataProvider(data: Data(source[start*80..<(start+400)*80]) as CFData)!
        return CIImage(cgImage: CGImage(width: 80,height: 400,bitsPerComponent: 8,bitsPerPixel: 8,bytesPerRow: 80,space: CGColorSpaceCreateDeviceGray(),bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),provider: provider,decode: nil,shouldInterpolate: false,intent: .defaultIntent)!)
    }
}
