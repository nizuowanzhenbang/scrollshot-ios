import Foundation
public enum StitchPlanner {
    /// Used by both PNG export and fullscreen preview to share final boundaries.
    public static func pages(segments: [StitchSegment],outer: CropInsets) throws -> [StitchSegment] {
        try segments.flatMap {try split(trim($0,top: outer.top,bottom: outer.bottom))}
    }
    public static func build(records: [FrameRecord], crop: CropInsets) throws -> [StitchSegment] {
        guard crop.top >= 0, crop.bottom >= 0 else { throw ScrollShotError.invalidInput("裁剪范围无效") }
        var result: [StitchSegment] = []
        var active: StitchSegment?
        var coverageEnd = 0, base = 0, scene = -1
        for r in records {
            guard r.width > 0, r.height > crop.top+crop.bottom, abs(r.offsetY) < 10_000_000 else {
                throw ScrollShotError.invalidInput("图像尺寸或裁剪范围无效")
            }
            let start = r.offsetY+crop.top, end = r.offsetY+r.height-crop.bottom
            if active == nil || r.segment != scene || start > coverageEnd || active?.width != r.width {
                if let a = active { result.append(a) }
                base = start; coverageEnd = start; scene = r.segment
                active = StitchSegment(width: r.width,height: 0,pieces: [])
            }
            if end > coverageEnd {
                let source = max(crop.top,coverageEnd-r.offsetY)
                let length = end-max(coverageEnd,start)
                active?.pieces.append(ImagePiece(fileName: r.fileName,sourceY: source,height: length,destinationY: coverageEnd-base))
                coverageEnd = end
                active?.height = end-base
            }
        }
        if let a = active { result.append(a) }
        return result
    }
    public static func split(_ segment: StitchSegment, maxHeight: Int = 60_000) throws -> [StitchSegment] {
        guard maxHeight > 0, segment.height > 0 else { throw ScrollShotError.invalidInput("输出尺寸无效") }
        return try stride(from: 0,to: segment.height,by: maxHeight).map {
            try trim(segment,top: $0,bottom: max(0,segment.height-$0-maxHeight))
        }
    }
    public static func trim(_ segment: StitchSegment, top: Int, bottom: Int) throws -> StitchSegment {
        let end = segment.height-bottom
        guard top >= 0, bottom >= 0, end > top else { throw ScrollShotError.invalidInput("至少保留一行图像") }
        let pieces = segment.pieces.compactMap { p -> ImagePiece? in
            let a = max(top,p.destinationY), b = min(end,p.destinationY+p.height)
            guard b > a else { return nil }
            return ImagePiece(fileName: p.fileName,sourceY: p.sourceY+a-p.destinationY,height: b-a,destinationY: a-top)
        }
        return StitchSegment(width: segment.width,height: end-top,pieces: pieces)
    }
}
public struct SamplerGate {
    private let interval: Double
    private var last: Double?
    public init(interval: Double = 0.2) { self.interval = max(0.01,interval) }
    public mutating func accept(timestamp: Double) -> Bool {
        guard timestamp.isFinite, timestamp >= 0 else { return false }
        if let last, timestamp-last < interval-0.000001 { return false }
        last = timestamp; return true
    }
}
