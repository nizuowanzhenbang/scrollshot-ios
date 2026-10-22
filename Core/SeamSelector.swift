import Foundation

public enum SeamSelector {
    /// Returns a row in the current frame. The corresponding previous-frame row
    /// is `row + displacement`. Keep both viewport edges out of the search.
    public static func currentRow(previous:GrayFrame,current:GrayFrame,displacement:Int,topInset:Int,bottomInset:Int,minimumRow:Int=0)->Int? {
        let w=previous.width,h=previous.height
        guard w>0,h>0,w==current.width,h==current.height,
              previous.pixels.count==w*h,current.pixels.count==w*h,
              topInset>=0,bottomInset>=0,topInset+bottomInset<h,
              displacement > -h,displacement<h else {return nil}
        let start=max(topInset,topInset-displacement)
        let end=min(h-bottomInset,h-bottomInset-displacement)
        guard end-start>=8 else {return nil}
        let margin=max(2,(end-start)/5),radius=min(4,margin-1)
        let lower=max(start+margin,minimumRow+radius),upper=end-margin
        guard lower<upper else {return nil}
        // Prefix sums keep the band comparison linear in image size. A quiet,
        // unchanged strip is preferable to cutting a glyph or animated sticker.
        var costs=[Double](repeating:0,count:end-start+1)
        let step=max(1,w/64)
        for y in start..<end {
            var difference=0.0,texture=0.0,count=0.0
            for x in stride(from:0,to:w,by:step) {
                let a=(y+displacement)*w+x,b=y*w+x
                difference+=abs(Double(previous.pixels[a])-Double(current.pixels[b]))
                if x>0 {
                    texture+=abs(Double(previous.pixels[a])-Double(previous.pixels[a-1]))
                    texture+=abs(Double(current.pixels[b])-Double(current.pixels[b-1]))
                }
                if y>0,y+displacement>0 {
                    texture+=abs(Double(previous.pixels[a])-Double(previous.pixels[a-w]))
                    texture+=abs(Double(current.pixels[b])-Double(current.pixels[b-w]))
                }
                count+=1
            }
            costs[y-start+1]=costs[y-start]+(4*difference+0.25*texture)/count
        }
        let middle=Double(start+end)/2
        var best=lower,bestScore=Double.infinity
        for y in lower..<upper {
            let a=y-radius-start,b=y+radius+1-start
            let score=(costs[b]-costs[a])/Double(b-a)+0.001*abs(Double(y)-middle)/Double(end-start)
            if score<bestScore {best=y;bestScore=score}
        }
        return best
    }
}

/// Keeps seam scoring aligned with the actual retained tail, including after
/// reverse captures which registered motion but did not extend image coverage.
public struct SeamTracker {
    private struct Reference {
        let gray:GrayFrame
        let offset:Int
        let nativeWidth:Int
        let scene:Int
        let end:Int
        let tailStart:Int
    }
    private var reference:Reference?
    public init() {}
    public mutating func preferredY(frame:GrayFrame,record:FrameRecord,crop:CropInsets)->Int? {
        let start=record.offsetY+crop.top,end=record.offsetY+record.height-crop.bottom
        guard let previous=reference,previous.scene==record.segment,previous.nativeWidth==record.width,
              previous.gray.width==frame.width,previous.gray.height==frame.height,start<=previous.end else {
            reference=Reference(gray:frame,offset:record.offsetY,nativeWidth:record.width,scene:record.segment,end:end,tailStart:start)
            return nil
        }
        guard end>previous.end else {return nil}
        let minimum=max(start,previous.tailStart)
        let row=SeamSelector.currentRow(previous:previous.gray,current:frame,displacement:record.offsetY-previous.offset,topInset:crop.top,bottomInset:crop.bottom,minimumRow:minimum-record.offsetY)
        let seam=StitchPlanner.seamY(start:start,coverageEnd:previous.end,tailStart:previous.tailStart,preferred:row.map {$0+record.offsetY})
        reference=Reference(gray:frame,offset:record.offsetY,nativeWidth:record.width,scene:record.segment,end:end,tailStart:seam)
        return seam
    }
}
