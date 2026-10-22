import XCTest
import CoreImage
import CoreGraphics
@testable import ScrollShotCore

final class ReviewRegressionTests: XCTestCase {
    func testNativeRefinementAndExportKeepEveryRowAcrossAnEstimatedSeam() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        let w = 64, h = 2400, shift = 220
        var source = fixture(width: w,height: h+shift)
        for y in 0..<(h+shift) {
            for x in 0..<w where y % 13 != 4 {
                source[y*w+x] = UInt8(20+(y%40)*4+(x*7)%30)
            }
        }
        var records: [FrameRecord] = []
        for (i,start) in [0,shift].enumerated() {
            let name = "\(i).png", writer = try PNGWriter(url: root.appendingPathComponent(name),width: w,height: h)
            let rgba = source[(start*w)..<((start+h)*w)].flatMap {[$0,$0,$0,255] as [UInt8]}
            try writer.append(rgba: Data(rgba),rowCount: h); try writer.finish()
            records.append(FrameRecord(fileName: name,width: w,height: h,offsetY: i*180,timestamp: Double(i)))
        }
        let crop = CropInsets(top: 300,bottom: 240)
        let refined = try Refinement.records(records,directory: root,crop: crop,progress: {_ in})
        XCTAssertEqual(refined.map(\.offsetY),[0,shift])
        let segments = try StitchPlanner.build(records: refined,crop: crop)
        XCTAssertEqual(segments.count,1)
        let segment = try XCTUnwrap(segments.first)
        let output = try RasterExporter.export(segment: segment,edit: PageEdit(),removeScrollbar: false,directory: root,outputDirectory: root.appendingPathComponent("out"),page: 0,progress: {_ in})
        let image = try FrameImaging.load(output.output)
        XCTAssertEqual(image.height,h+shift-crop.top-crop.bottom)
        let data = try XCTUnwrap(image.dataProvider?.data) as Data
        // Check every row, including both the seam and all 64/512-row strip boundaries.
        for y in 0..<image.height {
            XCTAssertEqual(data[y*image.bytesPerRow],source[(y+crop.top)*w],"Incorrect source row at \(y)")
        }
    }
    func testTallFixedHeaderCannotHideScrollingContent() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try SessionStore(root: root), pipeline = try CapturePipeline(store: store)
        var seed: UInt32 = 12345
        var content = [UInt8](repeating: 255,count: 256*600)
        for y in 0..<600 where y % 60 < 6 {
            for x in 36..<210 { seed = seed &* 1664525 &+ 1013904223; content[y*256+x] = UInt8(truncatingIfNeeded: seed >> 24) }
        }
        for (i,offset) in stride(from: 0,through: 150,by: 30).enumerated() {
            var pixels = [UInt8](repeating: 255,count: 256*550)
            for y in 0..<160 { for x in 0..<256 { pixels[y*256+x] = UInt8((y*107+x*73)%256) } }
            for y in 160..<550 { for x in 0..<256 { pixels[y*256+x] = content[(y-160+offset)*256+x] } }
            try pipeline.process(image: grayImage(pixels,width: 256,height: 550),timestamp: Double(i)*0.25)
        }
        try pipeline.finish()
        XCTAssertGreaterThan(pipeline.manifest.frames.count,1)
        XCTAssertEqual(pipeline.manifest.frames.last?.offsetY,150)
        XCTAssertEqual(Set(pipeline.manifest.frames.map(\.segment)).count,1)
    }
    func testRecroppingStartsFromOriginalRecordsAndRemovesOldExport() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try SessionStore(root: root)
        let session = try makeSession(store)
        try ExportService.generate(id: session.id,store: store,crop: CropInsets(top: 120,bottom: 120),outer: CropInsets(),progress: {_ in})
        let first = try store.load(session.id)
        XCTAssertEqual(first.outputs.count,2)
        XCTAssertEqual(first.frames,session.frames,"Export must never overwrite capture registration")
        try ExportService.generate(id: session.id,store: store,crop: CropInsets(),outer: CropInsets(),progress: {_ in})
        let second = try store.load(session.id)
        XCTAssertEqual(second.outputs.count,1,"Restoring crop must rejoin the original continuous scene")
        for name in first.outputs { XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory(for: session.id).appendingPathComponent(name).path)) }
        for record in session.frames { XCTAssertTrue(FileManager.default.fileExists(atPath: store.directory(for: session.id).appendingPathComponent(record.fileName).path)) }
    }
    func testFailedExportRemovesUnpublishedPagesAndKeepsPreviousResult() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try SessionStore(root: root)
        var session = try makeSession(store)
        try ExportService.generate(id: session.id,store: store,crop: CropInsets(),outer: CropInsets(),progress: {_ in})
        session = try store.load(session.id)
        let directory = store.directory(for: session.id)
        let oldOutputs = session.outputs
        session.frames[1].fileName = "missing.png"; try store.save(session)
        // First page finishes, then the second source fails: the first page must not leak.
        session.frames[1].segment = 1; try store.save(session)
        // Refinement reads all inputs first. Force the failure after refinement via progress.
        session.frames[1].fileName = "1.png"; try store.save(session)
        XCTAssertThrowsError(try ExportService.generate(id: session.id,store: store,crop: CropInsets(),outer: CropInsets(),progress: { p in
            if p > 0.5 { try? FileManager.default.removeItem(at: directory.appendingPathComponent("1.png")) }
        }))
        XCTAssertEqual(try store.load(session.id).outputs,oldOutputs)
        let exportDirectories = try FileManager.default.contentsOfDirectory(at: directory,includingPropertiesForKeys: nil).filter {$0.lastPathComponent.hasPrefix("export-")}
        XCTAssertEqual(exportDirectories.count,1)
        for name in oldOutputs { XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)) }
    }
    private func makeSession(_ store: SessionStore) throws -> SessionManifest {
        var session = try store.create(); session.state = .ready
        let source = fixture(width: 80,height: 550)
        for (index,start) in [0,140].enumerated() {
            let name = "\(index).png"
            let writer = try PNGWriter(url: store.directory(for: session.id).appendingPathComponent(name),width: 80,height: 400)
            let bytes = source[(start*80)..<((start+400)*80)].flatMap {[$0,$0,$0,255] as [UInt8]}
            try writer.append(rgba: Data(bytes),rowCount: 400);try writer.finish()
            session.frames.append(FrameRecord(fileName: name,width: 80,height: 400,offsetY: start,timestamp: Double(index)))
        }
        try store.save(session); return session
    }
    private func temporaryRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func grayImage(_ bytes: [UInt8],width: Int,height: Int) -> CIImage {
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CIImage(cgImage: CGImage(width: width,height: height,bitsPerComponent: 8,bitsPerPixel: 8,bytesPerRow: width,space: CGColorSpaceCreateDeviceGray(),bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),provider: provider,decode: nil,shouldInterpolate: false,intent: .defaultIntent)!)
    }
}
