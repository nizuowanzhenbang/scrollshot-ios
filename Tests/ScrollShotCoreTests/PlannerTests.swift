import XCTest
@testable import ScrollShotCore
final class PlannerTests: XCTestCase {
    func record(_ y: Int, _ segment: Int = 0, name: String = "a.jpg") -> FrameRecord {
        FrameRecord(fileName: name, width: 40, height: 100, offsetY: y, timestamp: 0, segment: segment)
    }
    func testOverlapOnlyAddsNewRows() throws {
        let p = try XCTUnwrap(StitchPlanner.build(records: [record(0), record(30, name: "b.jpg")], crop: CropInsets()).first)
        XCTAssertEqual(p.height, 130)
        XCTAssertEqual(p.pieces.last?.sourceY, 70)
        XCTAssertEqual(p.pieces.last?.height, 30)
        XCTAssertEqual(p.pieces.last?.destinationY, 100)
    }
    func testBackwardAndDuplicateDoNotRepeatRows() throws {
        let p = try XCTUnwrap(StitchPlanner.build(records: [record(0),record(30),record(10),record(30),record(50)], crop: CropInsets()).first)
        XCTAssertEqual(p.height, 150)
        XCTAssertEqual(p.pieces.map(\.height), [100,30,20])
    }
    func testCropRemovesFixedBarsFromEachFrame() throws {
        let p = try XCTUnwrap(StitchPlanner.build(records: [record(0),record(30)], crop: CropInsets(top: 10,bottom: 20)).first)
        XCTAssertEqual(p.height, 100)
        XCTAssertEqual(p.pieces.map(\.sourceY), [10,50])
        XCTAssertEqual(p.pieces.map(\.height), [70,30])
    }
    func testGapAndSceneChangeSplitInsteadOfGuessing() throws {
        let p = try StitchPlanner.build(records: [record(0),record(150),record(0,1)], crop: CropInsets())
        XCTAssertEqual(p.count, 3)
        XCTAssertEqual(p.map(\.height), [100,100,100])
    }
    func testInvalidCropAndDimensionsThrow() {
        XCTAssertThrowsError(try StitchPlanner.build(records: [record(0)], crop: CropInsets(top: 60,bottom: 40)))
        var b = record(20); b.width = 0
        XCTAssertThrowsError(try StitchPlanner.build(records: [b], crop: CropInsets()))
    }
    func testSplitPreservesEveryRowAtBoundary() throws {
        let p = try XCTUnwrap(StitchPlanner.build(records: [record(0),record(60)], crop: CropInsets()).first)
        let parts = try StitchPlanner.split(p,maxHeight: 75)
        XCTAssertEqual(parts.map(\.height), [75,75,10])
        XCTAssertEqual(parts[1].pieces.map(\.height), [25,50])
        XCTAssertEqual(parts[2].pieces.first?.sourceY, 90)
    }
    func testFinalTrimTranslatesSourceAndDestination() throws {
        let p = try XCTUnwrap(StitchPlanner.build(records: [record(0),record(30)], crop: CropInsets()).first)
        let t = try StitchPlanner.trim(p,top: 10,bottom: 5)
        XCTAssertEqual(t.height,115)
        XCTAssertEqual(t.pieces.map(\.sourceY),[10,70])
        XCTAssertEqual(t.pieces.map(\.height),[90,25])
        XCTAssertEqual(t.pieces.map(\.destinationY),[0,90])
    }
    func testGateLimitsToFivePerSecondAndRejectsInvalidTimes() {
        var gate = SamplerGate()
        XCTAssertTrue(gate.accept(timestamp: 0))
        XCTAssertFalse(gate.accept(timestamp: 0.1))
        XCTAssertTrue(gate.accept(timestamp: 0.2))
        XCTAssertFalse(gate.accept(timestamp: .nan))
        XCTAssertFalse(gate.accept(timestamp: -1))
        XCTAssertTrue(gate.accept(timestamp: 0.4))
    }
}
