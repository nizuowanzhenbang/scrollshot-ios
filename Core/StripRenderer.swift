import Foundation
import CoreGraphics
import CoreImage
public enum StripRenderer {
    public static func export(segment: StitchSegment,sessionDirectory: URL,outputDirectory: URL,progress: (Double)->Void) throws -> URL {
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: outputDirectory,withIntermediateDirectories: true)
        let output = outputDirectory.appendingPathComponent(UUID().uuidString+".png")
        let writer = try PNGWriter(url: output,width: segment.width,height: segment.height)
        var rows = 0, lastPercent = -1
        for piece in segment.pieces {
            try Task.checkCancellation()
            try autoreleasepool {
                let image = try FrameImaging.load(SessionStore.fileURL(piece.fileName,in: sessionDirectory))
                guard image.width == segment.width, piece.sourceY >= 0, piece.sourceY+piece.height <= image.height, piece.destinationY == rows else {
                    throw ScrollShotError.invalidInput("拼接计划与源图像不一致")
                }
                for offset in stride(from: 0,to: piece.height,by: 64) {
                    try Task.checkCancellation()
                    let count = min(64,piece.height-offset)
                    guard let strip = image.cropping(to: CGRect(x: 0,y: piece.sourceY+offset,width: segment.width,height: count)) else { throw ScrollShotError.io("图像裁剪失败") }
                    var rgba = Data(count: segment.width*count*4)
                    let ok = rgba.withUnsafeMutableBytes { raw -> Bool in
                        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
                        guard let c = CGContext(data: raw.baseAddress,width: segment.width,height: count,bitsPerComponent: 8,bytesPerRow: segment.width*4,space: CGColorSpace(name: CGColorSpace.sRGB)!,bitmapInfo: info) else { return false }
                        c.setFillColor(CGColor(gray: 1,alpha: 1)); c.fill(CGRect(x: 0,y: 0,width: segment.width,height: count))
                        c.draw(strip,in: CGRect(x: 0,y: 0,width: segment.width,height: count)); return true
                    }
                    guard ok else { throw ScrollShotError.io("无法创建导出条带") }
                    try writer.append(rgba: rgba,rowCount: count)
                    rows += count
                    let percent = rows*100/max(1,segment.height)
                    if percent != lastPercent { progress(Double(rows)/Double(segment.height)); lastPercent = percent }
                }
            }
        }
        try writer.finish()
        return output
    }
}

public enum Refinement {
    /// Refine in native vertical pixels; only horizontal resolution is reduced.
    public static func records(_ records: [FrameRecord],directory: URL,crop: CropInsets,progress: (Double)->Void) throws -> [FrameRecord] {
        let imaging = FrameImaging()
        var result: [FrameRecord] = [], previousGray: GrayFrame?, previousInput: FrameRecord?
        var position = 0, scene = -1
        var seams=SeamTracker()
        for (index,input) in records.enumerated() {
            try Task.checkCancellation()
            let gray: GrayFrame = try autoreleasepool {
                let image = try FrameImaging.load(SessionStore.fileURL(input.fileName,in: directory))
                return try imaging.gray(CIImage(cgImage: image),width: 64,height: image.height)
            }
            if let previousInput, let previousGray, previousInput.segment == input.segment,
               let match = Matcher.match(previous: previousGray,current: gray,topInset: max(crop.top,gray.height/8),bottomInset: max(crop.bottom,gray.height/10),expected: input.offsetY-previousInput.offsetY) {
                position += match.displacement
            } else { scene += 1; position = 0 }
            var record = input; record.offsetY = position; record.segment = scene
            record.preferredSeamY=seams.preferredY(frame:gray,record:record,crop:crop)
            result.append(record); previousGray = gray; previousInput = input
            progress(Double(index+1)/Double(max(1,records.count)))
        }
        return result
    }
}
