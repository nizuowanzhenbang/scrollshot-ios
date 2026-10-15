import Foundation
import CoreImage
public enum RecordingStop: Sendable {case idle,failed(String)}
public final class RecordingSession: @unchecked Sendable {
    public let id: UUID
    private let lock = NSLock()
    private var pipeline: CapturePipeline?
    private var detector: IdleStopDetector
    private var timer: DispatchSourceTimer?
    private let onStop: @Sendable(RecordingStop)->Void
    public init(store: SessionStore,preferences: CapturePreferences,onStop: @escaping @Sendable(RecordingStop)->Void) throws {
        let preferences = try preferences.validated(),pipeline = try CapturePipeline(store: store)
        self.pipeline = pipeline;id = pipeline.manifest.id;detector = IdleStopDetector(preferences: preferences);self.onStop = onStop
        if preferences.idleStopEnabled {
            let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
            self.timer = timer
            timer.schedule(deadline: .now()+0.1,repeating: .milliseconds(100),leeway: .milliseconds(10))
            timer.setEventHandler {[weak self] in self?.checkIdle()}
            timer.resume()
        }
    }
    deinit {timer?.cancel()}
    public func process(image: CIImage,timestamp: Double) throws {
        try lock.withLock {
            guard let activity = try pipeline?.process(image: image,timestamp: timestamp) else {return}
            detector.observe(activity,at: ProcessInfo.processInfo.systemUptime)
        }
    }
    public func pause() throws {try lock.withLock {try pipeline?.pause();detector.reset()}}
    public func resume() throws {try lock.withLock {try pipeline?.resume();detector.reset()}}
    public func finish(state: SessionState = .ready,reason: CaptureFinishReason = .manual) throws {
        try lock.withLock {
            defer {pipeline = nil;timer?.cancel();timer = nil}
            try pipeline?.finish(state: state,reason: reason)
        }
    }
    private func checkIdle() {
        let completion: RecordingStop? = lock.withLock {
            guard let pipeline,detector.poll(at: ProcessInfo.processInfo.systemUptime) else {return nil}
            defer {self.pipeline = nil;timer?.cancel();timer = nil}
            do {try pipeline.finish(reason: .idle);return .idle}
            catch {try? pipeline.finish(state: .interrupted,reason: .failed);return .failed(error.localizedDescription)}
        }
        // Call ReplayKit only after releasing our state lock: it may deliver
        // broadcastFinished while the callback is executing.
        if let completion {onStop(completion)}
    }
}
