import Foundation
import CoreGraphics
public struct PixelRect: Codable,Sendable,Equatable {
    public var x: Int;public var y: Int;public var width: Int;public var height: Int
    public init(x: Int,y: Int,width: Int,height: Int) {self.x=x;self.y=y;self.width=width;self.height=height}
}
public struct PageEdit: Codable,Sendable,Equatable {
    public var crop: PixelRect?
    public var mosaics: [PixelRect]
    public init(crop: PixelRect? = nil,mosaics: [PixelRect] = []) {self.crop=crop;self.mosaics=mosaics}
}
public struct RasterResult: Sendable {public let output: URL;public let tiles: [FrameRecord]}
public enum RasterExporter {
    public static func export(segment: StitchSegment,edit: PageEdit,removeScrollbar: Bool,directory: URL,outputDirectory: URL,page: Int,progress: (Double)->Void) throws -> RasterResult {
        RasterResult(output: try StripRenderer.export(segment: segment,sessionDirectory: directory,outputDirectory: outputDirectory,progress: progress),tiles: [])
    }
}
public enum ScrollbarCleaner {
    public static func detect(_ image: CGImage) -> [PixelRect] {[]}
}
public enum CompressionService {
    public static func generate(id: UUID,store: SessionStore,maxWidth: Int = 1080,maxHeight: Int = 8000,quality: Double = 0.8) throws -> SessionManifest {
        throw ScrollShotError.unavailable("尚未实现压缩")
    }
}
