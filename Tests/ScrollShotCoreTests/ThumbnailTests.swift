import XCTest
@testable import ScrollShotCore
final class ThumbnailTests: XCTestCase {
    func testDecodeIsBoundedAndRejectsInvalidCrop() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        defer {try? FileManager.default.removeItem(at: root)}
        let url = root.appendingPathComponent("large.png")
        let writer = try PNGWriter(url: url,width: 1000,height: 1200)
        for _ in 0..<12 {try writer.append(rgba: Data(repeating: 255,count: 1000*100*4),rowCount: 100)}
        try writer.finish()
        let image = try await ThumbnailDecoder.shared.decode(url: url,sourceY: 200,height: 400)
        XCTAssertLessThanOrEqual(image.width,900)
        XCTAssertEqual(image.height,300)
        do { _ = try await ThumbnailDecoder.shared.decode(url: url,sourceY: 1190,height: 50);XCTFail("Invalid source range accepted") } catch {}
    }
    func testCancelledPreviewDoesNotDecodeOrPublish() async throws {
        let task = Task {
            withUnsafeCurrentTask {$0?.cancel()}
            return try await ThumbnailDecoder.shared.decode(url: URL(fileURLWithPath: "/missing.png"),sourceY: 0,height: 10)
        }
        do { _ = try await task.value;XCTFail("Cancelled preview decoded") }
        catch {XCTAssertTrue(error is CancellationError)}
    }
}
