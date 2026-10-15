import Foundation
import CoreImage
public final class CapturePipeline {
    public private(set) var manifest: SessionManifest
    private let store: SessionStore
    private let imaging = FrameImaging()
    private var gate = SamplerGate()
    private var previous: GrayFrame?
    private var tail: CIImage?
    private var tailTime = 0.0
    private var position = 0.0
    private var lastStoredPosition: Double?
    private var scene = 0
    private var heartbeat = Date.distantPast
    public init(store: SessionStore) throws { self.store = store; manifest = try store.create() }
    public func process(image: CIImage,timestamp: Double) throws {
        guard manifest.state == .recording, gate.accept(timestamp: timestamp) else { return }
        let started = Date()
        let image = FrameImaging.normalized(image)
        guard image.extent.height > image.extent.width else { throw ScrollShotError.unavailable("当前版本请保持竖屏采集；已有内容已保留。") }
        let gray = try imaging.gray(image)
        var shouldWrite = previous == nil
        if let previous {
            if let match = Matcher.match(previous: previous,current: gray,topInset: gray.height/8,bottomInset: gray.height/10) {
                position += Double(match.displacement)*image.extent.width/Double(gray.width)
                shouldWrite = position-(lastStoredPosition ?? position) >= image.extent.height*0.08
            } else if Matcher.difference(previous,gray) > 0.015 {
                scene += 1; position = 0; lastStoredPosition = nil; shouldWrite = true
                if !manifest.warnings.contains("部分画面缺少可靠重叠，已分为独立片段。") { manifest.warnings.append("部分画面缺少可靠重叠，已分为独立片段。") }
            }
        }
        self.previous = gray; tail = image; tailTime = timestamp
        if shouldWrite { try storeTail() }
        manifest.maxProcessingMs = max(manifest.maxProcessingMs,Date().timeIntervalSince(started)*1000)
        if Date().timeIntervalSince(heartbeat) >= 2 { try store.save(manifest); heartbeat = Date() }
    }
    private func storeTail() throws {
        guard let tail else { return }
        let free = try? store.root.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity
        if let free, free < 64*1024*1024 { throw ScrollShotError.io("存储空间不足，已保留当前草稿。") }
        let name = String(format: "%06d.jpg",manifest.frames.count)
        let data = try imaging.jpeg(tail)
        try store.writeFrame(data,fileName: name,session: manifest.id)
        manifest.frames.append(FrameRecord(fileName: name,width: Int(tail.extent.width),height: Int(tail.extent.height),offsetY: Int(position.rounded()),timestamp: tailTime,segment: scene))
        lastStoredPosition = position
        try store.save(manifest)
    }
    public func pause() throws { manifest.state = .paused; try store.save(manifest) }
    public func resume() throws {
        manifest.state = .recording; gate = SamplerGate(); previous = nil; tail = nil
        scene += 1; position = 0; lastStoredPosition = nil; try store.save(manifest)
    }
    public func finish(state: SessionState = .ready) throws {
        if let lastStoredPosition, position-lastStoredPosition >= 1 { try storeTail() }
        manifest.state = state; tail = nil; previous = nil; try store.save(manifest)
    }
}
