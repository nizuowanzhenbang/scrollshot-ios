import XCTest
@testable import ScrollShotCore

final class SeamTests: XCTestCase {
    func testNativeWidthChangeStartsSeamScoringWithTheNewSegment() throws {
        let w=64,h=100,crop=CropInsets(top:10,bottom:10)
        var source=fixture(width:w,height:130)
        for y in 50..<70 {for x in 0..<w {source[y*w+x]=20}}
        let old=GrayFrame(width:w,height:h,pixels:frame(source,width:w,start:0,height:h).pixels.map {255-$0})
        let first=frame(source,width:w,start:0,height:h),next=frame(source,width:w,start:30,height:h)
        let records=[FrameRecord(fileName:"old.png",width:100,height:h,offsetY:0,timestamp:0),FrameRecord(fileName:"first.png",width:200,height:h,offsetY:0,timestamp:1),FrameRecord(fileName:"next.png",width:200,height:h,offsetY:30,timestamp:2)]
        var fresh=SeamTracker()
        _=fresh.preferredY(frame:first,record:records[1],crop:crop)
        let expected=try XCTUnwrap(fresh.preferredY(frame:next,record:records[2],crop:crop))
        var mixed=SeamTracker()
        _=mixed.preferredY(frame:old,record:records[0],crop:crop)
        _=mixed.preferredY(frame:first,record:records[1],crop:crop)
        XCTAssertEqual(mixed.preferredY(frame:next,record:records[2],crop:crop),expected,"A prior native-width segment must not influence the new segment")
    }
    func testSequenceKeepsItsSeamsInsideTheRetainedPreviousPiece() throws {
        let w=64,h=100,offsets=[0,10,20]
        var source=fixture(width:w,height:120)
        for range in [35..<51,55..<73] {for y in range {for x in 0..<w {source[y*w+x]=20}}}
        var frames=offsets.map {frame(source,width:w,start:$0,height:h)}
        for (index,range) in [(0,35..<51),(2,55..<73)] {
            var pixels=frames[index].pixels
            for y in range {for x in 0..<w {pixels[(y-offsets[index])*w+x]=80}}
            frames[index]=GrayFrame(width:w,height:h,pixels:pixels)
        }
        var tracker=SeamTracker(),records:[FrameRecord]=[]
        for i in offsets.indices {
            var r=FrameRecord(fileName:"\(i).png",width:w,height:h,offsetY:offsets[i],timestamp:Double(i))
            r.preferredSeamY=tracker.preferredY(frame:frames[i],record:r,crop:CropInsets())
            records.append(r)
        }
        let first=try XCTUnwrap(records[1].preferredSeamY),second=try XCTUnwrap(records[2].preferredSeamY)
        XCTAssertGreaterThanOrEqual(second,first,"Never score against a frame and then discard it at an earlier seam")
        let plan=try XCTUnwrap(StitchPlanner.build(records:records,crop:CropInsets()).first)
        XCTAssertTrue(plan.pieces.contains {$0.fileName=="1.png"})
    }
    func testSequenceScoresTheRetainedCoverageFrameAfterReverseMotion() throws {
        let w=64,h=100,offsets=[0,30,10,50]
        var source=fixture(width:w,height:150)
        for range in [36..<60,70..<86,92..<110] {for y in range {for x in 0..<w {source[y*w+x]=20}}}
        var frames=offsets.map {frame(source,width:w,start:$0,height:h)}
        var changed=frames[1].pixels
        for y in 70..<86 {for x in 0..<w {changed[(y-30)*w+x]=80}}
        frames[1]=GrayFrame(width:w,height:h,pixels:changed)
        var tracker=SeamTracker(),seams:[Int?]=[]
        for i in offsets.indices {
            let r=FrameRecord(fileName:"\(i).png",width:w,height:h,offsetY:offsets[i],timestamp:Double(i))
            seams.append(tracker.preferredY(frame:frames[i],record:r,crop:CropInsets(top:10,bottom:10)))
        }
        XCTAssertNil(seams[2],"A reverse capture does not extend retained coverage")
        XCTAssertTrue((92..<110).contains(try XCTUnwrap(seams[3])),"Compare with retained frame 1 rather than discarded reverse frame 2")
    }
    func testSeamAvoidsAnimatedContentAndChoosesAnUnchangedBlankBand() throws {
        let w=64,h=160,d=40
        var a=[UInt8](repeating:20,count:w*h),b=a
        for y in 0..<h {for x in 0..<w {
            a[y*w+x]=UInt8(30+((x+y)%2)*180)
            b[y*w+x]=UInt8(30+((x+y+d)%2)*180)
        }}
        // The normal middle of the overlap falls inside an animated sticker.
        for y in 55..<90 {for x in 0..<w {b[y*w+x]=UInt8((x*73+y*37)%256)}}
        // Both frames contain the same document whitespace above the sticker.
        for y in 28..<44 {for x in 0..<w {a[(y+d)*w+x]=20;b[y*w+x]=20}}
        let row=try XCTUnwrap(SeamSelector.currentRow(previous:GrayFrame(width:w,height:h,pixels:a),current:GrayFrame(width:w,height:h,pixels:b),displacement:d,topInset:10,bottomInset:10))
        XCTAssertTrue((30..<42).contains(row),"Choose unchanged whitespace rather than the animated middle")
    }
    func testSelectedRowHasTheSameDocumentCoordinateWhenDirectionReverses() throws {
        let source=fixture(width:32,height:220)
        let a=frame(source,width:32,start:0,height:160),b=frame(source,width:32,start:40,height:160)
        let forward=try XCTUnwrap(SeamSelector.currentRow(previous:a,current:b,displacement:40,topInset:10,bottomInset:10))
        let reverse=try XCTUnwrap(SeamSelector.currentRow(previous:b,current:a,displacement:-40,topInset:10,bottomInset:10))
        XCTAssertEqual(reverse,forward+40)
    }
    func testInvalidFramesAndInsufficientOverlapHaveNoPreferredSeam() {
        let a=GrayFrame(width:32,height:100,pixels:Array(repeating:20,count:3200))
        let invalid=GrayFrame(width:32,height:100,pixels:[])
        XCTAssertNil(SeamSelector.currentRow(previous:a,current:invalid,displacement:20,topInset:0,bottomInset:0))
        XCTAssertNil(SeamSelector.currentRow(previous:a,current:a,displacement:98,topInset:0,bottomInset:0))
    }
}
