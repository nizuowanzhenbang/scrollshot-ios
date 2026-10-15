import Foundation
import CoreImage
public enum RecordingStop: Sendable {case idle,failed(String)}
public final class RecordingSession: @unchecked Sendable {
    public let id: UUID
    private let pipeline: CapturePipeline
    public init(store: SessionStore,preferences: CapturePreferences,onStop: @escaping @Sendable(RecordingStop)->Void) throws {
        pipeline = try CapturePipeline(store: store);id = pipeline.manifest.id
    }
    public func process(image: CIImage,timestamp: Double) throws {try pipeline.process(image: image,timestamp: timestamp)}
    public func pause() throws {try pipeline.pause()}
    public func resume() throws {try pipeline.resume()}
    public func finish(state: SessionState = .ready,reason: CaptureFinishReason = .manual) throws {try pipeline.finish(state: state)}
}
