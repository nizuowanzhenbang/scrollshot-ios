import ReplayKit
import CoreImage
import ImageIO
import ScrollShotCore

final class SampleHandler: RPBroadcastSampleHandler {
    private var pipeline: CapturePipeline?
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        do {
            let access = CaptureAccess.inspect(bundleURL: Bundle.main.bundleURL) {FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)}
            guard let container = access.container else {
                throw ScrollShotError.unavailable(access.diagnostics)
            }
            pipeline = try CapturePipeline(store: SessionStore(root: container.drafts))
        } catch { stop(error) }
    }
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video, CMSampleBufferIsValid(sampleBuffer),let buffer = CMSampleBufferGetImageBuffer(sampleBuffer),let pipeline else { return }
        do {
            try autoreleasepool {
                let attachment = CMGetAttachment(sampleBuffer,key: RPVideoSampleOrientationKey as CFString,attachmentModeOut: nil) as? NSNumber
                let orientation = CGImagePropertyOrientation(rawValue: attachment?.uint32Value ?? 1) ?? .up
                let image = CIImage(cvPixelBuffer: buffer).oriented(orientation)
                try pipeline.process(image: image,timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds)
            }
        } catch { stop(error) }
    }
    override func broadcastPaused() { do { try pipeline?.pause() } catch { stop(error) } }
    override func broadcastResumed() { do { try pipeline?.resume() } catch { stop(error) } }
    override func broadcastFinished() { try? pipeline?.finish(); pipeline = nil }
    private func stop(_ error: Error) {
        try? pipeline?.finish(state: .interrupted); pipeline = nil
        finishBroadcastWithError(error as NSError)
    }
}
