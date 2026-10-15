import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
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
public struct RasterResult: Sendable {public let output: URL;public let tiles: [FrameRecord]}
public enum RasterExporter {
    public static func export(segment: StitchSegment,edit: PageEdit,removeScrollbar: Bool,directory: URL,outputDirectory: URL,page: Int,progress: (Double)->Void) throws -> RasterResult {
        let crop=try (edit.crop ?? PixelRect(x:0,y:0,width:segment.width,height:segment.height)).validated(width:segment.width,height:segment.height)
        for mask in edit.mosaics {_ = try mask.validated(width:segment.width,height:segment.height)}
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        let output=outputDirectory.appendingPathComponent("page-\(page).png"),writer=try PNGWriter(url:output,width:crop.width,height:crop.height)
        var tiles:[FrameRecord]=[],tile:PNGWriter?,tileRows=0,tileHeight=0,total=0
        for piece in segment.pieces {
            let a=max(crop.y,piece.destinationY),b=min(crop.y+crop.height,piece.destinationY+piece.height)
            guard b>a else {continue}
            try autoreleasepool {
                let image=try FrameImaging.load(SessionStore.fileURL(piece.fileName,in:directory))
                let bars=removeScrollbar ? ScrollbarCleaner.detect(image):[]
                guard image.width==segment.width,piece.sourceY>=0,piece.sourceY+piece.height<=image.height else {throw ScrollShotError.invalidInput("拼接计划无效")}
                var y=a
                while y<b {
                    try Task.checkCancellation()
                    if tile==nil {
                        tileRows=0;tileHeight=min(512,crop.height-total)
                        let name="tile-\(page)-\(tiles.count).png"
                        tile=try PNGWriter(url:outputDirectory.appendingPathComponent(name),width:crop.width,height:tileHeight)
                        tiles.append(FrameRecord(fileName:outputDirectory.lastPathComponent+"/"+name,width:crop.width,height:tileHeight,offsetY:total,timestamp:0,segment:page))
                    }
                    let n=min(64,b-y,tileHeight-tileRows),sourceY=piece.sourceY+y-piece.destinationY
                    guard let strip=image.cropping(to:CGRect(x:crop.x,y:sourceY,width:crop.width,height:n)) else {throw ScrollShotError.io("裁剪失败")}
                    var data=Data(count:crop.width*n*4)
                    let ok=data.withUnsafeMutableBytes {raw -> Bool in
                        guard let c=CGContext(data:raw.baseAddress,width:crop.width,height:n,bitsPerComponent:8,bytesPerRow:crop.width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {return false}
                        c.setFillColor(CGColor(gray:1,alpha:1));c.fill(CGRect(x:0,y:0,width:crop.width,height:n));c.draw(strip,in:CGRect(x:0,y:0,width:crop.width,height:n));return true
                    }
                    guard ok else {throw ScrollShotError.io("图片缓冲创建失败")}
                    let original=[UInt8](data)
                    data.withUnsafeMutableBytes {raw in
                        let p=raw.bindMemory(to:UInt8.self)
                        for row in 0..<n {
                            for bar in bars where sourceY+row>=bar.y && sourceY+row<bar.y+bar.height {
                                let l=max(0,bar.x-crop.x),r=min(crop.width,bar.x+bar.width-crop.x)
                                guard r>l else {continue}
                                let left=max(0,l-1),right=min(crop.width-1,r)
                                for x in l..<r {for c in 0..<3 {let v=(Int(original[(row*crop.width+left)*4+c])+Int(original[(row*crop.width+right)*4+c]))/2;p[(row*crop.width+x)*4+c]=UInt8(v)}}
                            }
                            for mask in edit.mosaics where y+row>=mask.y && y+row<mask.y+mask.height {
                                let l=max(crop.x,mask.x),r=min(crop.x+crop.width,mask.x+mask.width)
                                guard r>l else {continue}
                                let sampleY=min(n-1,max(0,mask.y+((y+row-mask.y)/24)*24-y))
                                for x in l..<r {
                                    let sampleX=min(crop.width-1,max(0,mask.x+((x-mask.x)/24)*24-crop.x)),source=(sampleY*crop.width+sampleX)*4,dest=(row*crop.width+x-crop.x)*4
                                    for c in 0..<3 {p[dest+c]=original[source+c]};p[dest+3]=255
                                }
                            }
                        }
                    }
                    try writer.append(rgba:data,rowCount:n);try tile?.append(rgba:data,rowCount:n)
                    total+=n;tileRows+=n;y+=n
                    if tileRows==tileHeight {try tile?.finish();tile=nil}
                    progress(Double(total)/Double(crop.height))
                }
            }
        }
        guard total==crop.height else {throw ScrollShotError.invalidInput("裁剪区域缺少图像")}
        try writer.finish();return RasterResult(output:output,tiles:tiles)
    }
}
public enum ScrollbarCleaner {
    public static func detect(_ image: CGImage) -> [PixelRect] {
        let w=image.width,h=image.height,band=min(w,max(12,w/40)),radius=max(3,min(10,w/150))
        guard band>radius*2,h>30,let cut=image.cropping(to:CGRect(x:w-band,y:0,width:band,height:h)) else {return []}
        var bytes=[UInt8](repeating:0,count:band*h*4)
        let ok=bytes.withUnsafeMutableBytes {raw -> Bool in
            guard let c=CGContext(data:raw.baseAddress,width:band,height:h,bitsPerComponent:8,bytesPerRow:band*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {return false};c.draw(cut,in:CGRect(x:0,y:0,width:band,height:h));return true
        }
        guard ok else {return []}
        func gray(_ x:Int,_ y:Int)->Int {let i=(y*band+x)*4;return (Int(bytes[i])+Int(bytes[i+1])+Int(bytes[i+2]))/3}
        var found:[PixelRect]=[]
        for x in radius..<(band-radius) {
            var start:Int?,lo=255,hi=0
            func finish(_ end:Int) {
                if let s=start,end-s>=max(24,h/40),end-s<=h/2,hi-lo<25 {found.append(PixelRect(x:w-band+x,y:s,width:1,height:end-s))}
                start=nil;lo=255;hi=0
            }
            for y in 1..<h-1 {
                let a=gray(x-radius,y),b=gray(x+radius,y),v=gray(x,y)
                let i=(y*band+x)*4,channels=[Int(bytes[i]),Int(bytes[i+1]),Int(bytes[i+2])]
                if abs(a-b)<18,abs(v-(a+b)/2)>35,(channels.max()! - channels.min()!)<18 {
                    if start==nil {start=y};lo=min(lo,v);hi=max(hi,v)
                } else {finish(y)}
            };finish(h-1)
        }
        var merged:[PixelRect]=[]
        for value in found {
            if let last=merged.last,abs(last.y-value.y)<4,abs(last.height-value.height)<6,last.x+last.width==value.x {
                merged[merged.count-1].width+=1
            } else {merged.append(value)}
        }
        return merged.filter{$0.width>=2 && $0.width<=radius*2}.map {r in PixelRect(x:max(w-band,r.x-1),y:max(0,r.y-2),width:min(w-r.x+1,r.width+2),height:min(h-r.y+2,r.height+4))}
    }
}
public enum CompressionService {
    public static func generate(id: UUID,store: SessionStore,maxWidth: Int = 1080,maxHeight: Int = 8000,quality: Double = 0.8) throws -> SessionManifest {
        guard (1...2048).contains(maxWidth),(1...8192).contains(maxHeight),quality.isFinite,(0.1...1).contains(quality) else {throw ScrollShotError.invalidInput("压缩参数无效")}
        var session=try store.load(id)
        guard session.state != .recording,session.state != .paused,let tiles=session.renderedTiles,!tiles.isEmpty else {throw ScrollShotError.unavailable("请先生成长图再压缩")}
        let directory=store.directory(for:id),folder="compressed-"+UUID().uuidString,out=directory.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        var committed=false,names:[String]=[]
        defer {if !committed {try? FileManager.default.removeItem(at:out)}}
        func file(_ name:String)throws->URL {
            let url=directory.appendingPathComponent(name).standardizedFileURL
            guard url.path.hasPrefix(directory.standardizedFileURL.path+"/") else {throw ScrollShotError.invalidInput("图像路径无效")};return url
        }
        for (page,group) in Dictionary(grouping:tiles,by:{$0.segment}).sorted(by:{$0.key<$1.key}) {
            let group=group.sorted{$0.offsetY<$1.offsetY},width=group[0].width
            var sourceHeight=0
            for tile in group {guard tile.width==width,tile.height>0,tile.offsetY==sourceHeight else {throw ScrollShotError.invalidInput("预览图块不连续")};sourceHeight+=tile.height}
            let scale=min(1,Double(maxWidth)/Double(width)),w=max(1,Int((Double(width)*scale).rounded())),h=max(1,Int((Double(sourceHeight)*scale).rounded()))
            for top in stride(from:0,to:h,by:maxHeight) {
                try Task.checkCancellation()
                let height=min(maxHeight,h-top),name="\(folder)/page-\(page)-\(top).jpg"
                try autoreleasepool {
                    guard let context=CGContext(data:nil,width:w,height:height,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {throw ScrollShotError.io("压缩缓冲创建失败")}
                    context.setFillColor(CGColor(gray:1,alpha:1));context.fill(CGRect(x:0,y:0,width:w,height:height))
                    for tile in group {
                        let a=Double(tile.offsetY)*scale,b=Double(tile.offsetY+tile.height)*scale
                        guard b>Double(top),a<Double(top+height) else {continue}
                        try Task.checkCancellation()
                        // Tile offsets start at the image top; Quartz drawing
                        // coordinates start at the bottom of this JPEG page.
                        try autoreleasepool {let image=try FrameImaging.load(file(tile.fileName));context.draw(image,in:CGRect(x:0,y:Double(height)-(b-Double(top)),width:Double(w),height:b-a))}
                    }
                    guard let image=context.makeImage(),let destination=CGImageDestinationCreateWithURL(try file(name) as CFURL,UTType.jpeg.identifier as CFString,1,nil) else {throw ScrollShotError.io("JPEG 创建失败")}
                    CGImageDestinationAddImage(destination,image,[kCGImageDestinationLossyCompressionQuality:quality] as CFDictionary)
                    guard CGImageDestinationFinalize(destination) else {throw ScrollShotError.io("JPEG 保存失败")}
                };names.append(name)
            }
        }
        let original=try session.outputs.reduce(0) {$0 + (try Data(contentsOf:file($1),options:.mappedIfSafe).count)}
        let compressed=try names.reduce(0) {$0 + (try Data(contentsOf:file($1),options:.mappedIfSafe).count)}
        guard compressed<original else {throw ScrollShotError.unavailable("原图已经较小，本次压缩没有变小；已保留原图。")}
        let previous=session.compressedOutputs ?? []
        session.compressedOutputs=names;try Task.checkCancellation();try store.save(session);committed=true
        for folder in Set(previous.compactMap{$0.split(separator:"/").first.map(String.init)}) where folder.hasPrefix("compressed-") && UUID(uuidString:String(folder.dropFirst(11))) != nil {try? FileManager.default.removeItem(at:directory.appendingPathComponent(folder))}
        return session
    }
}
