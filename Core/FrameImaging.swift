import Foundation
import CoreImage
import ImageIO
import CoreGraphics

public final class FrameImaging {
    private let context = CIContext(options: [.cacheIntermediates: false])
    public init() {}
    public static func normalized(_ image: CIImage) -> CIImage {
        image.transformed(by: CGAffineTransform(translationX: -image.extent.minX,y: -image.extent.minY))
    }
    public func gray(_ image: CIImage,width: Int = 256,height: Int? = nil) throws -> GrayFrame {
        let image = Self.normalized(image)
        let w = min(width,Int(image.extent.width)), h = height ?? Int((image.extent.height*Double(w)/image.extent.width).rounded())
        guard w >= 1, h >= 1, h <= 20_000 else { throw ScrollShotError.invalidInput("采集图像尺寸无效") }
        let scaled = image.transformed(by: CGAffineTransform(scaleX: Double(w)/image.extent.width,y: Double(h)/image.extent.height))
        guard let cg = context.createCGImage(scaled,from: CGRect(x: 0,y: 0,width: w,height: h)) else {
            throw ScrollShotError.io("无法创建分析图像")
        }
        var pixels = [UInt8](repeating: 0,count: w*h)
        let ok = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let c = CGContext(data: raw.baseAddress,width: w,height: h,bitsPerComponent: 8,bytesPerRow: w,space: CGColorSpaceCreateDeviceGray(),bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            c.interpolationQuality = .low
            c.draw(cg,in: CGRect(x: 0,y: 0,width: w,height: h)); return true
        }
        guard ok else { throw ScrollShotError.io("无法分配分析缓冲") }
        return GrayFrame(width: w,height: h,pixels: pixels)
    }
    public func jpeg(_ image: CIImage) throws -> Data {
        let options = [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.96]
        guard let data = context.jpegRepresentation(of: Self.normalized(image),colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,options: options) else {
            throw ScrollShotError.io("无法保存采集帧")
        }
        return data
    }
    public static func load(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL,[kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateImageAtIndex(source,0,nil) else { throw ScrollShotError.io("无法读取图像：\(url.lastPathComponent)") }
        return image
    }
}
