import XCTest
import AVFoundation
@testable import ScrollShotCore

final class VideoImportTests: XCTestCase {
    func testRealVideoDecodeProducesRecoverableOrderedFrames() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try SessionStore(root: root.appendingPathComponent("drafts"))
        defer {try? FileManager.default.removeItem(at: root)}
        let url = root.appendingPathComponent("fixture.mov")
        let writer = try AVAssetWriter(outputURL: url,fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video,outputSettings: [AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:80,AVVideoHeightKey:400])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:80,kCVPixelBufferHeightKey as String:400])
        writer.add(input); XCTAssertTrue(writer.startWriting()); writer.startSession(atSourceTime: .zero)
        let source = fixture(width: 80,height: 600)
        for i in 0..<6 {
            let deadline = Date().addingTimeInterval(10)
            while !input.isReadyForMoreMediaData {
                if Date()>deadline {XCTFail("Video encoder did not become ready");return}
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            var optional: CVPixelBuffer?
            XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault,80,400,kCVPixelFormatType_32ARGB,nil,&optional),kCVReturnSuccess)
            let buffer = try XCTUnwrap(optional)
            CVPixelBufferLockBaseAddress(buffer,[])
            let pointer = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(buffer)
            for y in 0..<400 {for x in 0..<80 {
                let v = source[(y+i*30)*80+x], p = y*stride+x*4
                pointer[p] = 255; pointer[p+1] = v; pointer[p+2] = v; pointer[p+3] = v
            }}
            CVPixelBufferUnlockBaseAddress(buffer,[])
            XCTAssertTrue(adaptor.append(buffer,withPresentationTime: CMTime(value: Int64(i),timescale: 5)))
        }
        input.markAsFinished(); await writer.finishWriting()
        XCTAssertEqual(writer.status,.completed)
        let result = try await ImportService.importVideo(url: url,store: store,progress: {_ in})
        XCTAssertEqual(result.state,.ready)
        XCTAssertGreaterThanOrEqual(result.frames.count,3)
        XCTAssertEqual(result.frames.first?.offsetY,0)
        XCTAssertEqual(Double(try XCTUnwrap(result.frames.last).offsetY),150.0,accuracy: 2.0)
        XCTAssertEqual(try store.load(result.id).frames,result.frames)
        let children = try FileManager.default.contentsOfDirectory(atPath: store.directory(for: result.id).path)
        XCTAssertFalse(children.contains(where: {$0.hasPrefix("import-")}))
    }
}
