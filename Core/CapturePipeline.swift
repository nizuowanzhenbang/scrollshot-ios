import Foundation
import CoreImage
public final class CapturePipeline {
    public private(set) var manifest: SessionManifest
    private let store: SessionStore
    public init(store: SessionStore) throws { self.store = store; manifest = try store.create() }
    public func process(image: CIImage,timestamp: Double) throws {}
    public func pause() throws {}
    public func resume() throws {}
    public func finish(state: SessionState = .ready) throws { manifest.state = state; try store.save(manifest) }
}
