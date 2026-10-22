import XCTest
@testable import ScrollShotCore
final class PlannerTests: XCTestCase {
    func testInteriorSeamsExcludeResidualFixedBarsWithoutLosingDocumentRows() throws {
        let records = [record(0,name:"a.jpg"),record(30,name:"b.jpg"),record(60,name:"c.jpg")]
        let plan = try XCTUnwrap(StitchPlanner.build(records:records,crop:CropInsets(top:10,bottom:10)).first)
        var rows:[Int]=[]
        for piece in plan.pieces {
            let input = try XCTUnwrap(records.first {$0.fileName==piece.fileName})
            for y in piece.sourceY..<(piece.sourceY+piece.height) {
                // The actual fixed bars are two rows taller than the crop.
                rows.append(y<12 || y>=88 ? -1:input.offsetY+y)
            }
        }
        XCTAssertEqual(plan.height,140)
        // The outermost bars are user-croppable. Internal rows must come from
        // unobscured overlap, even when the source has correct registration.
        XCTAssertEqual(Array(rows.dropFirst(2).dropLast(2)),Array(12..<148))
    }
    func record(_ y: Int, _ segment: Int = 0, name: String = "a.jpg") -> FrameRecord {
        FrameRecord(fileName: name, width: 40, height: 100, offsetY: y, timestamp: 0, segment: segment)
    }
    func testOverlapReplacesTheOldTailAtAnInteriorSeam() throws {
        let p = try XCTUnwrap(StitchPlanner.build(records: [record(0), record(30, name: "b.jpg")], crop: CropInsets()).first)
        XCTAssertEqual(p.height, 130)
        XCTAssertEqual(p.pieces.last?.sourceY, 35)
        XCTAssertEqual(p.pieces.last?.height, 65)
        XCTAssertEqual(p.pieces.last?.destinationY, 65)
    }
    func testBackwardAndDuplicateDoNotRepeatRows() throws {
        let p = try XCTUnwrap(StitchPlanner.build(records: [record(0),record(30),record(10),record(30),record(50)], crop: CropInsets()).first)
        XCTAssertEqual(p.height, 150)
        XCTAssertEqual(p.pieces.map(\.height), [65,32,53])
    }
    func testCropRemovesFixedBarsFromEachFrame() throws {
        let p = try XCTUnwrap(StitchPlanner.build(records: [record(0),record(30)], crop: CropInsets(top: 10,bottom: 20)).first)
        XCTAssertEqual(p.height, 100)
        XCTAssertEqual(p.pieces.map(\.sourceY), [10,30])
        XCTAssertEqual(p.pieces.map(\.height), [50,50])
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
        XCTAssertEqual(parts[1].pieces.map(\.height), [5,70])
        XCTAssertEqual(parts[2].pieces.first?.sourceY, 90)
    }
    func testFinalTrimTranslatesSourceAndDestination() throws {
        let p = try XCTUnwrap(StitchPlanner.build(records: [record(0),record(30)], crop: CropInsets()).first)
        let t = try StitchPlanner.trim(p,top: 10,bottom: 5)
        XCTAssertEqual(t.height,115)
        XCTAssertEqual(t.pieces.map(\.sourceY),[10,35])
        XCTAssertEqual(t.pieces.map(\.height),[55,60])
        XCTAssertEqual(t.pieces.map(\.destinationY),[0,55])
    }
    func testSeamReplacementWithReverseMotionPreservesEveryDocumentRow() throws {
        var records=[0,37,15,37,82,130,129,175].enumerated().map {record($0.element,name:"\($0.offset).jpg")}
        records[4].preferredSeamY=95
        records[5].preferredSeamY=Int.max // Clamp a stale preference to valid overlap.
        let plan=try XCTUnwrap(StitchPlanner.build(records:records,crop:CropInsets(top:7,bottom:11)).first)
        var document:[Int]=[]
        for piece in plan.pieces {
            let input=try XCTUnwrap(records.first {$0.fileName==piece.fileName})
            XCTAssertEqual(piece.destinationY,document.count)
            XCTAssertGreaterThanOrEqual(piece.sourceY,7)
            XCTAssertLessThanOrEqual(piece.sourceY+piece.height,89)
            document += (piece.sourceY..<(piece.sourceY+piece.height)).map {input.offsetY+$0}
        }
        XCTAssertEqual(document,Array(7..<264))
        XCTAssertEqual(plan.height,document.count)
    }
    func testOldFrameRecordsWithoutSeamMetadataStillDecode() throws {
        let data=Data(#"{"fileName":"a.jpg","width":40,"height":100,"offsetY":0,"timestamp":0,"segment":0}"#.utf8)
        var input=try JSONDecoder().decode(FrameRecord.self,from:data)
        XCTAssertNil(input.preferredSeamY)
        input.preferredSeamY=35
        XCTAssertEqual(try JSONDecoder().decode(FrameRecord.self,from:JSONEncoder().encode(input)),input)
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
