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
