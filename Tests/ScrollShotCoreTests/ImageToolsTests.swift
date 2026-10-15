import XCTest
import ImageIO
import CoreGraphics
@testable import ScrollShotCore
final class ImageToolsTests: XCTestCase {
    func testCompressedTilesKeepTopBottomOrderAcrossPageBreakInsideTile() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:root)}
        let store=try SessionStore(root:root);var session=try store.create();session.state = .ready
        let dir=store.directory(for:session.id),w=120,h=1024
        let original=try PNGWriter(url:dir.appendingPathComponent("original.png"),width:w,height:h)
        var tiles:[FrameRecord]=[],seed:UInt64=234
        for t in 0..<2 {
            let name="tile-\(t).png",writer=try PNGWriter(url:dir.appendingPathComponent(name),width:w,height:512)
            for _ in 0..<512 {
                var row=Data()
                for _ in 0..<w {seed=seed &* 6364136223846793005 &+ 1;let n=UInt8((seed>>32)%55);row.append(contentsOf:t==0 ? [200,n,0,255]:[0,n,200,255])}
                try writer.append(rgba:row,rowCount:1);try original.append(rgba:row,rowCount:1)
            }
            try writer.finish();tiles.append(FrameRecord(fileName:name,width:w,height:512,offsetY:t*512,timestamp:0))
        }
        try original.finish();session.outputs=["original.png"];session.renderedTiles=tiles;try store.save(session)
        let result=try CompressionService.generate(id:session.id,store:store,maxWidth:w,maxHeight:600,quality:0.7)
        let names=try XCTUnwrap(result.compressedOutputs);XCTAssertEqual(names.count,2)
        func rgb(_ file:String,_ row:Int)throws->[UInt8] {
            let image=try FrameImaging.load(dir.appendingPathComponent(file)),data=try XCTUnwrap(image.dataProvider?.data) as Data
            let stride=image.bitsPerPixel/8,start=row*image.bytesPerRow+40*stride
            return Array(data[start..<start+3])
        }
        let top=try rgb(names[0],30),before=try rgb(names[0],480),after=try rgb(names[0],560),tail=try rgb(names[1],30)
        XCTAssertGreaterThan(top[0],150);XCTAssertLessThan(top[2],50)
        XCTAssertGreaterThan(before[0],150);XCTAssertLessThan(before[2],50)
        XCTAssertGreaterThan(after[2],150);XCTAssertLessThan(after[0],50)
        XCTAssertGreaterThan(tail[2],150);XCTAssertLessThan(tail[0],50)
    }
    func testToolSettingsPersistAndInvalidThresholdCannotReplaceThem() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:root)}
        let store=ToolPreferencesStore(root:root)
        XCTAssertEqual(try store.load().compressionPromptMB,20)
        var prefs=ToolPreferences();prefs.smartScrollbar=false;prefs.haptics=false;prefs.compressionPromptMB=33.5
        try store.save(prefs);XCTAssertEqual(try store.load(),prefs)
        for invalid in [0.0,-1,.nan,.infinity] {var bad=prefs;bad.compressionPromptMB=invalid;XCTAssertThrowsError(try store.save(bad))}
        XCTAssertEqual(try store.load(),prefs)
    }
    func testCompressionProducesSmallerBoundedCopiesAndKeepsPNG() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:root)}
        let store=try SessionStore(root:root);var session=try store.create();session.state = .ready
        let dir=store.directory(for:session.id),url=dir.appendingPathComponent("original.png")
        let w=120,h=1000,writer=try PNGWriter(url:url,width:w,height:h)
        var seed:UInt64=123
        for _ in 0..<h {var data=Data();for _ in 0..<w {seed=seed &* 6364136223846793005 &+ 1;let v=UInt8(truncatingIfNeeded:seed>>32);data.append(contentsOf:[v,v,v,255])};try writer.append(rgba:data,rowCount:1)}
        try writer.finish();session.outputs=["original.png"]
        session.renderedTiles=[FrameRecord(fileName:"original.png",width:w,height:h,offsetY:0,timestamp:0)]
        try store.save(session)
        let result=try CompressionService.generate(id:session.id,store:store,maxWidth:60,maxHeight:250,quality:0.7)
        let names=try XCTUnwrap(result.compressedOutputs);XCTAssertEqual(names.count,2)
        var total=0
        for name in names {let path=dir.appendingPathComponent(name),image=try FrameImaging.load(path);XCTAssertEqual(image.width,60);XCTAssertLessThanOrEqual(image.height,250);total += try Data(contentsOf:path).count}
        XCTAssertLessThan(total,try Data(contentsOf:url).count)
        XCTAssertEqual(result.outputs,["original.png"]);XCTAssertTrue(FileManager.default.fileExists(atPath:url.path))
    }
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
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:root)}
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let input=root.appendingPathComponent("bar.png"),destination=CGImageDestinationCreateWithURL(input as CFURL,"public.png" as CFString,1,nil)!
        CGImageDestinationAddImage(destination,bar,nil);XCTAssertTrue(CGImageDestinationFinalize(destination))
        let segment=try StitchPlanner.build(records:[FrameRecord(fileName:"bar.png",width:w,height:h,offsetY:0,timestamp:0)],crop:CropInsets())[0]
        for enabled in [false,true] {
            let output=try RasterExporter.export(segment:segment,edit:PageEdit(),removeScrollbar:enabled,directory:root,outputDirectory:root.appendingPathComponent(enabled ? "clean":"kept"),page:0,progress:{_ in})
            let image=try FrameImaging.load(output.output),data=try XCTUnwrap(image.dataProvider?.data) as Data
            XCTAssertEqual(data[150*image.bytesPerRow+395*4],enabled ? 245:100)
            XCTAssertEqual(data[150*image.bytesPerRow+380*4],245,"Neighbor content must remain unchanged")
        }
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
