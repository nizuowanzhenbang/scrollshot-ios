import Foundation
import CoreGraphics
import ImageIO

/// A single shared actor bounds all preview decoding to one image at a time.
public actor ThumbnailDecoder {
    public static let shared = ThumbnailDecoder()
    public func decode(url: URL,sourceY: Int,height: Int) throws -> CGImage {
        try Task.checkCancellation()
        return try autoreleasepool {
            guard let source = CGImageSourceCreateWithURL(url as CFURL,nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
                  let originalHeight = properties[kCGImagePropertyPixelHeight] as? Int,
                  sourceY >= 0,height > 0,height <= originalHeight,sourceY <= originalHeight-height,
                  let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:900,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) else {
                throw ScrollShotError.io("无法生成预览")
            }
            try Task.checkCancellation()
            let scale = Double(image.height)/Double(originalHeight)
            let rect = CGRect(x: 0,y: Double(sourceY)*scale,width: Double(image.width),height: Double(height)*scale).integral
            guard let cut = image.cropping(to: rect) else { throw ScrollShotError.io("预览裁剪失败") }
            return cut
        }
    }
}
