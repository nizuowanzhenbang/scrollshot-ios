import XCTest
import ImageIO
@testable import ScrollShotCore
final class RenderTests: XCTestCase {
    func testSixtyFourRowStripsKeepTheBoundaryPixel() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        defer {try? FileManager.default.removeItem(at: root)}
        let input = root.appendingPathComponent("rows.png")
        let writer = try PNGWriter(url: input,width: 4,height: 130)
        let bytes = (0..<130).flatMap {row in Array(repeating: [UInt8(row),0,0,255],count: 4).flatMap {$0}}
        try writer.append(rgba: Data(bytes),rowCount: 130);try writer.finish()
        let r = FrameRecord(fileName: "rows.png",width: 4,height: 130,offsetY: 0,timestamp: 0)
        let plan = try XCTUnwrap(StitchPlanner.build(records: [r],crop: CropInsets()).first)
        let out = try StripRenderer.export(segment: plan,sessionDirectory: root,outputDirectory: root,progress: {_ in})
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(out as CFURL,nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source,0,nil))
        let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertEqual([63,64,127,128,129].map {pixels[$0*image.bytesPerRow]},[63,64,127,128,129])
    }
    func testStripsPreserveSourceRowOrderAndSeam() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("a.png"), b = root.appendingPathComponent("b.png")
        func write(_ url: URL,_ values: [UInt8]) throws {
            let writer = try PNGWriter(url: url,width: 4,height: values.count)
            for v in values { try writer.append(rgba: Data(Array(repeating: [v,v,v,255],count: 4).flatMap {$0}),rowCount: 1) }
            try writer.finish()
        }
        try write(a,[10,20,30,40]); try write(b,[30,40,50,60])
        let records = [FrameRecord(fileName: "a.png",width: 4,height: 4,offsetY: 0,timestamp: 0),FrameRecord(fileName: "b.png",width: 4,height: 4,offsetY: 2,timestamp: 1)]
        let segment = try XCTUnwrap(StitchPlanner.build(records: records,crop: CropInsets()).first)
        let output = try StripRenderer.export(segment: segment,sessionDirectory: root,outputDirectory: root,progress: {_ in})
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(output as CFURL,nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source,0,nil))
        let data = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertEqual(image.height,6)
        XCTAssertEqual((0..<6).map {data[$0*image.bytesPerRow]},[10,20,30,40,50,60])
    }
}
