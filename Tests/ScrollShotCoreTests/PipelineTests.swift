import XCTest
import CoreImage
import CoreGraphics
@testable import ScrollShotCore
final class PipelineTests: XCTestCase {
    func testCaptureAcceptsMotionButThrottlesIntermediateFrame() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try SessionStore(root: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let pipeline = try CapturePipeline(store: store)
        let source = fixture(width: 80,height: 500)
        try pipeline.process(image: image(source,start: 0),timestamp: 0)
        try pipeline.process(image: image(source,start: 25),timestamp: 0.1)
        try pipeline.process(image: image(source,start: 50),timestamp: 0.2)
        try pipeline.finish()
        let m = try store.load(pipeline.manifest.id)
        XCTAssertEqual(m.frames.count,2)
        XCTAssertEqual(m.frames.map(\.offsetY),[0,50])
        XCTAssertEqual(m.state,.ready)
        for f in m.frames { XCTAssertTrue(FileManager.default.fileExists(atPath: store.directory(for: m.id).appendingPathComponent(f.fileName).path)) }
    }
    func testPauseResumeStartsANewContinuitySegment() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try SessionStore(root: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let pipeline = try CapturePipeline(store: store)
        let source = fixture(width: 80,height: 500)
        try pipeline.process(image: image(source,start: 0),timestamp: 0)
        try pipeline.pause(); try pipeline.resume()
        try pipeline.process(image: image(source,start: 30),timestamp: 1)
        try pipeline.finish(state: .interrupted)
        XCTAssertEqual(pipeline.manifest.frames.map(\.segment),[0,1])
        XCTAssertEqual(try store.load(pipeline.manifest.id).state,.interrupted)
    }
    private func image(_ source: [UInt8],start: Int) -> CIImage {
        let bytes = Data(source[(start*80)..<((start+400)*80)])
        let provider = CGDataProvider(data: bytes as CFData)!
        let cg = CGImage(width: 80,height: 400,bitsPerComponent: 8,bitsPerPixel: 8,bytesPerRow: 80,space: CGColorSpaceCreateDeviceGray(),bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),provider: provider,decode: nil,shouldInterpolate: false,intent: .defaultIntent)!
        return CIImage(cgImage: cg)
    }
}
