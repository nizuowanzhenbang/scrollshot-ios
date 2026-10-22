import Foundation

public struct PixelRect: Codable,Sendable,Equatable {
    public var x: Int;public var y: Int;public var width: Int;public var height: Int
    public init(x: Int,y: Int,width: Int,height: Int) {self.x=x;self.y=y;self.width=width;self.height=height}
    public func validated(width w:Int,height h:Int) throws -> Self {
        guard x>=0,y>=0,width>0,height>0,width<=w,height<=h,x<=w-width,y<=h-height else {throw ScrollShotError.invalidInput("选择区域超出图片范围")};return self
    }
}
public struct PageEdit: Codable,Sendable,Equatable {
    public var crop: PixelRect?
    public var mosaics: [PixelRect]
    public init(crop: PixelRect? = nil,mosaics: [PixelRect] = []) {self.crop=crop;self.mosaics=mosaics}
}
