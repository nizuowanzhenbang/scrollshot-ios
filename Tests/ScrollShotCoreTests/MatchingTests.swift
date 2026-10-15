import XCTest
@testable import ScrollShotCore
final class MatchingTests: XCTestCase {
    func testDetectsDownwardShift() throws {
        let source = fixture(width: 40, height: 140)
        let a = frame(source, width: 40, start: 0, height: 100)
        let b = frame(source, width: 40, start: 17, height: 100)
        let result = try XCTUnwrap(Matcher.match(previous: a, current: b))
        XCTAssertEqual(result.displacement, 17)
        XCTAssertLessThan(result.error, 0.01)
    }
    func testReverseAndRepeatedFrames() throws {
        let source = fixture(width: 40,height: 140)
        let a = frame(source,width: 40,start: 0,height: 100)
        let b = frame(source,width: 40,start: 17,height: 100)
        XCTAssertEqual(try XCTUnwrap(Matcher.match(previous: b,current: a)).displacement,-17)
        XCTAssertEqual(try XCTUnwrap(Matcher.match(previous: a,current: a)).displacement,0)
    }
    func testUniformAndUnrelatedImagesAreNotTrusted() {
        let flat = GrayFrame(width: 40,height: 100,pixels: Array(repeating: 255,count: 4000))
        XCTAssertNil(Matcher.match(previous: flat,current: flat))
        let source = fixture(width: 40,height: 250)
        XCTAssertNil(Matcher.match(previous: frame(source,width: 40,start: 0,height: 100),current: frame(source,width: 40,start: 140,height: 100)))
    }
    func testFixedBarsExcludedFromComparison() throws {
        let source = fixture(width: 40,height: 160)
        let a = frame(source,width: 40,start: 0,height: 100)
        var pixels = frame(source,width: 40,start: 20,height: 100).pixels
        for y in 0..<15 { for x in 0..<40 { pixels[y*40+x] = a.pixels[y*40+x] } }
        for y in 85..<100 { for x in 0..<40 { pixels[y*40+x] = a.pixels[y*40+x] } }
        let b = GrayFrame(width: 40,height: 100,pixels: pixels)
        XCTAssertEqual(try XCTUnwrap(Matcher.match(previous: a,current: b,topInset: 15,bottomInset: 15)).displacement,20)
    }
}
func fixture(width: Int, height: Int) -> [UInt8] {
    var seed: UInt64 = 0x12345678
    return (0..<(width * height)).map { _ in
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return UInt8(truncatingIfNeeded: seed >> 32)
    }
}
func frame(_ source: [UInt8], width: Int, start: Int, height: Int) -> GrayFrame {
    GrayFrame(width: width, height: height, pixels: Array(source[(start * width)..<((start + height) * width)]))
}
