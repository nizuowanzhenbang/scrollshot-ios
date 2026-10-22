import XCTest
@testable import ScrollShotCore
final class MatchingTests: XCTestCase {
    func testNativeRefinementRecoversMoreThanTwelvePixelsOfCoarseError() throws {
        let source = fixture(width: 64,height: 2800)
        let a = frame(source,width: 64,start: 0,height: 2400)
        let b = frame(source,width: 64,start: 220,height: 2400)
        let result = try XCTUnwrap(Matcher.match(previous: a,current: b,expected: 200))
        XCTAssertEqual(result.displacement,220)
        XCTAssertEqual(try XCTUnwrap(Matcher.match(previous: b,current: a,expected: -200)).displacement,-220)
    }
    func testNativeRefinementDoesNotSkipThinTextBetweenSampledRows() throws {
        // At height 2400 the old matcher samples every 13th row. Identical
        // separators on those rows hide the unique thin text between them.
        let w = 64, h = 2400, shift = 131
        var source = [UInt8](repeating: 20,count: w*(h+shift))
        let noise = fixture(width: w,height: h+shift)
        for y in 0..<(h+shift) {
            for x in 0..<w {
                if y % 13 == 0 { source[y*w+x] = UInt8(40+(x*17)%180) }
                if y % 13 == 4 { source[y*w+x] = noise[y*w+x] }
            }
        }
        let a = frame(source,width: w,start: 0,height: h)
        let b = frame(source,width: w,start: shift,height: h)
        let result = try XCTUnwrap(Matcher.match(previous: a,current: b,expected: shift))
        XCTAssertEqual(result.displacement,shift)
    }
    func testNativeRefinementCannotConfuseRepeatedRowsWithTheTrueOverlap() throws {
        let w = 64, h = 2400, shift = 220
        let noise = fixture(width: w,height: h+shift)
        var source = noise
        for y in 0..<(h+shift) {
            for x in 0..<w where y % 13 != 4 {
                source[y*w+x] = UInt8(20+(y%40)*4+(x*7)%30)
            }
        }
        let result = try XCTUnwrap(Matcher.match(
            previous: frame(source,width: w,start: 0,height: h),
            current: frame(source,width: w,start: shift,height: h),expected: 180))
        XCTAssertEqual(result.displacement,shift,"A confident 180px match would delete 40 rows at this seam")
    }
    func testNativeRefinementHonorsFixedBarsAndToleratesSmallPixelNoise() throws {
        let w = 64, h = 1200, shift = 147
        let source = fixture(width: w,height: h+shift)
        let a = frame(source,width: w,start: 0,height: h)
        var pixels = frame(source,width: w,start: shift,height: h).pixels
        for y in 0..<h {
            for x in 0..<w {
                let i = y*w+x
                if y < 180 || y >= h-140 { pixels[i] = a.pixels[i] }
                else { pixels[i] = UInt8(clamping: Int(pixels[i])+(i%7)-3) }
            }
        }
        let b = GrayFrame(width: w,height: h,pixels: pixels)
        let result = try XCTUnwrap(Matcher.match(previous: a,current: b,topInset: 180,bottomInset: 140,expected: 125))
        XCTAssertEqual(result.displacement,shift)
    }
    func testNativeRefinementRejectsAmbiguousRepeatedRows() {
        let w = 64, h = 1200
        var pixels = [UInt8](repeating: 0,count: w*h)
        for y in 0..<h {
            for x in 0..<w { pixels[y*w+x] = UInt8((y%20)*10+x%10) }
        }
        let a = GrayFrame(width: w,height: h,pixels: pixels)
        XCTAssertNil(Matcher.match(previous: a,current: a,expected: 80))
    }
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
