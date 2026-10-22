import XCTest
import ImageIO
@testable import ScrollShotCore
final class RenderTests: XCTestCase {
    func testResidualFixedBarsDoNotRepeatAtInternalPNGSeams() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:root)}
        let w=40,h=100,source=fixture(width:40,height:160)
        var records:[FrameRecord]=[]
        for (i,offset) in [0,30,60].enumerated() {
            let name="\(i).png",writer=try PNGWriter(url:root.appendingPathComponent(name),width:w,height:h)
            var bytes=Data()
            for y in 0..<h {for x in 0..<w {
                let value:UInt8 = y<12 || y>=88 ? 0:source[(offset+y)*w+x]
                bytes.append(contentsOf:[value,value,value,255])
            }}
            try writer.append(rgba:bytes,rowCount:h);try writer.finish()
            records.append(FrameRecord(fileName:name,width:w,height:h,offsetY:offset,timestamp:Double(i)))
        }
        let crop=CropInsets(top:10,bottom:10)
        let refined=try Refinement.records(records,directory:root,crop:crop,progress:{_ in})
        XCTAssertEqual(refined.map(\.offsetY),[0,30,60])
        XCTAssertNotNil(refined.last?.preferredSeamY)
        let segments=try StitchPlanner.build(records:refined,crop:crop)
        XCTAssertEqual(segments.count,1)
        let output=try RasterExporter.export(segment:XCTUnwrap(segments.first),edit:PageEdit(),removeScrollbar:false,directory:root,outputDirectory:root.appendingPathComponent("out"),page:0,progress:{_ in})
        let image=try FrameImaging.load(output.output),data=try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertEqual(image.height,140)
        for y in 2..<(image.height-2) {
            XCTAssertEqual((0..<w).map {data[y*image.bytesPerRow+$0*4]},Array(source[((y+10)*w)..<((y+11)*w)]),"Unexpected content at row \(y)")
        }
    }
    func testSixtyFourRowStripsKeepTheBoundaryPixel() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        defer {try? FileManager.default.removeItem(at: root)}
        let input = root.appendingPathComponent("rows.png")
        let writer = try PNGWriter(url: input,width: 4,height: 130)
        var bytes = [UInt8]()
        for row in 0..<130 { for _ in 0..<4 { bytes.append(contentsOf: [UInt8(row),0,0,255]) } }
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
