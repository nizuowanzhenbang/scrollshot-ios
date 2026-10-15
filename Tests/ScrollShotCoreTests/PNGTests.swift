import XCTest
import ImageIO
import CoreGraphics
@testable import ScrollShotCore
final class PNGTests: XCTestCase {
    func testRGBAAndRowOrderRoundTripAcrossAppends() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".png")
        defer { try? FileManager.default.removeItem(at: url) }
        let bytes: [UInt8] = [255,0,0,255, 0,255,0,255, 0,0,255,255, 255,255,0,255, 12,34,56,128, 0,0,0,0]
        let writer = try PNGWriter(url: url,width: 2,height: 3)
        try writer.append(rgba: Data(bytes[0..<8]),rowCount: 1)
        try writer.append(rgba: Data(bytes[8..<24]),rowCount: 2)
        try writer.finish()
        let src = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL,nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(src,0,nil))
        XCTAssertEqual(image.width,2); XCTAssertEqual(image.height,3)
        let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertEqual(Array(pixels),bytes)
    }
    func testIncompletePNGDoesNotPublishOutput() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".png")
        let writer = try PNGWriter(url: url,width: 2,height: 2)
        XCTAssertThrowsError(try writer.append(rgba: Data([1]),rowCount: 1))
        XCTAssertThrowsError(try writer.finish())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
