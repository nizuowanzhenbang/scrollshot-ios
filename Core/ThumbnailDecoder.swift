import Foundation
import CoreGraphics
import ImageIO

/// A single shared actor bounds all preview decoding to one image at a time.
public actor ThumbnailDecoder {
    public static let shared = ThumbnailDecoder()
    public func decode(url: URL,sourceY: Int,height: Int,maxPixelSize: Int = 900) throws -> CGImage {
        try Task.checkCancellation()
        return try autoreleasepool {
            guard let source = CGImageSourceCreateWithURL(url as CFURL,nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
                  let originalHeight = properties[kCGImagePropertyPixelHeight] as? Int,
                  sourceY >= 0,height > 0,height <= originalHeight,sourceY <= originalHeight-height else {
                throw ScrollShotError.io("无法生成预览")
            }
            let longest = max(originalHeight,(properties[kCGImagePropertyPixelWidth] as? Int) ?? originalHeight)
            let bound = min(longest,max(1,min(4096,maxPixelSize)))
            guard let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:bound,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) else {throw ScrollShotError.io("无法生成预览")}
            try Task.checkCancellation()
            let scale = Double(image.height)/Double(originalHeight)
            let rect = CGRect(x: 0,y: Double(sourceY)*scale,width: Double(image.width),height: Double(height)*scale).integral
            guard let cut = image.cropping(to: rect) else { throw ScrollShotError.io("预览裁剪失败") }
            // Copy the slice so a tiny visible piece cannot retain a complete
            // high-resolution source frame through CGImage's cropping provider.
            guard let context = CGContext(data: nil,width: cut.width,height: cut.height,bitsPerComponent: 8,bytesPerRow: cut.width*4,space: CGColorSpace(name: CGColorSpace.sRGB)!,bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {throw ScrollShotError.io("预览缓冲创建失败")}
            context.draw(cut,in: CGRect(x: 0,y: 0,width: cut.width,height: cut.height))
            try Task.checkCancellation()
            guard let output = context.makeImage() else {throw ScrollShotError.io("预览缓冲创建失败")}
            return output
        }
    }
}
