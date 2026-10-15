import Foundation
import CZlib
public final class PNGWriter {
    private let url: URL
    private let temporary: URL
    private let width: Int
    private let height: Int
    private let handle: FileHandle
    private var stream = z_stream()
    private var initialized = false
    private var rows = 0
    private var finished = false
    public init(url: URL, width: Int, height: Int) throws {
        guard width > 0, width <= 16_384, height > 0, height <= 60_000 else { throw ScrollShotError.invalidInput("PNG 尺寸无效") }
        self.url = url; self.width = width; self.height = height
        temporary = url.deletingLastPathComponent().appendingPathComponent(".writing-"+UUID().uuidString)
        guard !FileManager.default.fileExists(atPath: url.path), FileManager.default.createFile(atPath: temporary.path,contents: nil) else {
            throw ScrollShotError.io("无法创建输出文件")
        }
        handle = try FileHandle(forWritingTo: temporary)
        let result = deflateInit_(&stream,Z_DEFAULT_COMPRESSION,ZLIB_VERSION,Int32(MemoryLayout<z_stream>.size))
        guard result == Z_OK else { try? handle.close(); try? FileManager.default.removeItem(at: temporary); throw ScrollShotError.io("无法启动 PNG 压缩") }
        initialized = true
        try handle.write(contentsOf: Data([137,80,78,71,13,10,26,10]))
        var ihdr = Self.big(UInt32(width)); ihdr.append(Self.big(UInt32(height))); ihdr.append(contentsOf: [8,6,0,0,0])
        try chunk("IHDR",data: ihdr)
    }
    deinit {
        if initialized { deflateEnd(&stream) }
        try? handle.close()
        if !finished { try? FileManager.default.removeItem(at: temporary) }
    }
    public func append(rgba: Data, rowCount: Int) throws {
        guard !finished, rowCount > 0, rows+rowCount <= height, rgba.count == width*4*rowCount else {
            throw ScrollShotError.invalidInput("PNG 行数据长度无效")
        }
        // Limit staging even if a caller supplies a large strip.
        for start in stride(from: 0,to: rowCount,by: 64) {
            let n = min(64,rowCount-start), strideBytes = width*4
            var filtered = Data(); filtered.reserveCapacity(n*(strideBytes+1))
            for row in start..<(start+n) {
                filtered.append(0)
                filtered.append(rgba[(row*strideBytes)..<((row+1)*strideBytes)])
            }
            try compress(filtered,flush: Z_NO_FLUSH)
        }
        rows += rowCount
    }
    public func finish() throws {
        guard !finished, rows == height else { throw ScrollShotError.invalidInput("PNG 图像还未完整写入") }
        try compress(Data(),flush: Z_FINISH)
        try chunk("IEND",data: Data())
        try handle.synchronize(); try handle.close()
        try FileManager.default.moveItem(at: temporary,to: url)
        finished = true
    }
    private func compress(_ data: Data,flush: Int32) throws {
        try data.withUnsafeBytes { input in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: input.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(data.count)
            var status: Int32 = Z_OK
            repeat {
                var output = [UInt8](repeating: 0,count: 65_536)
                let produced = output.withUnsafeMutableBytes { buffer -> Int in
                    stream.next_out = buffer.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(buffer.count)
                    status = deflate(&stream,flush)
                    return buffer.count-Int(stream.avail_out)
                }
                guard status == Z_OK || status == Z_STREAM_END else { throw ScrollShotError.io("PNG 压缩失败：\(status)") }
                if produced > 0 { try chunk("IDAT",data: Data(output.prefix(produced))) }
            } while stream.avail_in > 0 || stream.avail_out == 0 || (flush == Z_FINISH && status != Z_STREAM_END)
            stream.next_in = nil; stream.next_out = nil
        }
    }
    private func chunk(_ name: String,data: Data) throws {
        var typed = Data(name.utf8); typed.append(data)
        let crc = typed.withUnsafeBytes { crc32(0,$0.bindMemory(to: Bytef.self).baseAddress,uInt($0.count)) }
        try handle.write(contentsOf: Self.big(UInt32(data.count)))
        try handle.write(contentsOf: typed)
        try handle.write(contentsOf: Self.big(UInt32(truncatingIfNeeded: crc)))
    }
    private static func big(_ v: UInt32) -> Data {
        var x = v.bigEndian
        return withUnsafeBytes(of: &x) {Data($0)}
    }
}
