import XCTest
import ImageIO
import CoreGraphics
@testable import ScrollShotCore
final class ImageToolsTests: XCTestCase {
    func testActualCropAndMosaicPixelsAndBoundedPreviewTiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at: root)}
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        let w=80,h=1100,url=root.appendingPathComponent("frame.png")
        let writer=try PNGWriter(url:url,width:w,height:h)
        for y in 0..<h {var row=Data();for x in 0..<w {row.append(contentsOf:[UInt8(x*3),UInt8(y%251),UInt8((x+y)%251),255])};try writer.append(rgba:row,rowCount:1)}
        try writer.finish()
        let segment=try StitchPlanner.build(records:[FrameRecord(fileName:"frame.png",width:w,height:h,offsetY:0,timestamp:0)],crop:CropInsets())[0]
        let result=try RasterExporter.export(segment:segment,edit:PageEdit(crop:PixelRect(x:10,y:20,width:60,height:1000),mosaics:[PixelRect(x:20,y:30,width:24,height:24)]),removeScrollbar:false,directory:root,outputDirectory:root.appendingPathComponent("out"),page:0,progress:{_ in})
        let image=try FrameImaging.load(result.output)
        XCTAssertEqual(image.width,60);XCTAssertEqual(image.height,1000)
        XCTAssertEqual(result.tiles.map(\.height).reduce(0,+),1000);XCTAssertTrue(result.tiles.allSatisfy{$0.height<=512 && $0.width==60})
        let pixels=try XCTUnwrap(image.dataProvider?.data) as Data
        if image.width==60,image.height==1000 {
            XCTAssertEqual(pixels[0],30);XCTAssertEqual(pixels[1],20)
            let a=10*image.bytesPerRow+10*4,b=11*image.bytesPerRow+11*4
            XCTAssertEqual(Array(pixels[a..<a+3]),Array(pixels[b..<b+3]),"Mosaic must change the actual exported pixels")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath:url.path))
    }
    func testConservativeScrollbarDetection() throws {
        let w=400,h=800
        var pixels=[UInt8](repeating:245,count:w*h*4)
        for i in stride(from:3,to:pixels.count,by:4) {pixels[i]=255}
        let p=CGDataProvider(data:Data(pixels) as CFData)!
        let blank=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:p,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
        XCTAssertTrue(ScrollbarCleaner.detect(blank).isEmpty)
        for y in 120..<280 {for x in 394..<397 {let i=(y*w+x)*4;pixels[i]=100;pixels[i+1]=100;pixels[i+2]=100}}
        let q=CGDataProvider(data:Data(pixels) as CFData)!
        let bar=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:q,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
        XCTAssertFalse(ScrollbarCleaner.detect(bar).isEmpty)
    }
    func testDeletionRefusesActiveSessionAndRemovesFinishedDraft() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:root)}
        let store=try SessionStore(root:root);var a=try store.create()
        XCTAssertThrowsError(try store.delete(a.id));XCTAssertNotNil(try? store.load(a.id))
        a.state = .ready;try store.save(a);try store.delete(a.id)
        XCTAssertTrue(try store.all().isEmpty)
    }
}
