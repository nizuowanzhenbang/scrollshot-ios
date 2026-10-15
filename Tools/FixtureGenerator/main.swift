import Foundation
import ScrollShotCore
let root = URL(fileURLWithPath: CommandLine.arguments[1],isDirectory: true)
let store = try SessionStore(root: root)
var session = try store.create()
let w = 128, h = 400
var seed: UInt64 = 777
let source: [UInt8] = (0..<(w*780)).map { _ in
    seed = seed &* 6364136223846793005 &+ 1
    return UInt8(truncatingIfNeeded: seed >> 32)
}
for (i,y) in [0,140,280].enumerated() {
    let name = "fixture-\(i).png"
    let writer = try PNGWriter(url: store.directory(for: session.id).appendingPathComponent(name),width: w,height: h)
    for row in 0..<h {
        var bytes = [UInt8](); bytes.reserveCapacity(w*4)
        for x in 0..<w {let v = source[(row+y)*w+x];bytes += [v,v,v,255]}
        try writer.append(rgba: Data(bytes),rowCount: 1)
    }
    try writer.finish()
    session.frames.append(FrameRecord(fileName: name,width: w,height: h,offsetY: y,timestamp: Double(i),segment: 0))
}
session.state = .ready
try store.save(session)
print(session.id.uuidString)
