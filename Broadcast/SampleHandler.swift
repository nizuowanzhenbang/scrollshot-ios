import ReplayKit
import CoreImage
import ImageIO
import ScrollShotCore

final class SampleHandler: RPBroadcastSampleHandler {
    private var recording: RecordingSession?
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        do {
            let access = CaptureAccess.inspect(bundleURL: Bundle.main.bundleURL) {FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)}
            guard let container = access.container else {
                throw ScrollShotError.unavailable(access.diagnostics)
            }
            let preferences = try CapturePreferencesStore(root: container.drafts).load()
            recording = try RecordingSession(store: SessionStore(root: container.drafts),preferences: preferences) {[weak self] completion in
                let text: String,code: Int
                switch completion {
                case .idle:text = "已停滑 \(preferences.effectiveIdleSeconds) 秒，截图已完成。返回轻卷截图查看。";code = 0
                case .failed(let message):text = message;code = 1
                }
                self?.finishBroadcastWithError(NSError(domain: "ScrollShot.Recording",code: code,userInfo: [NSLocalizedDescriptionKey:text]))
            }
        } catch { stop(error) }
    }
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video, CMSampleBufferIsValid(sampleBuffer),let buffer = CMSampleBufferGetImageBuffer(sampleBuffer),let recording else { return }
        do {
            try autoreleasepool {
                let attachment = CMGetAttachment(sampleBuffer,key: RPVideoSampleOrientationKey as CFString,attachmentModeOut: nil) as? NSNumber
                let orientation = CGImagePropertyOrientation(rawValue: attachment?.uint32Value ?? 1) ?? .up
                let image = CIImage(cvPixelBuffer: buffer).oriented(orientation)
                try recording.process(image: image,timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds)
            }
        } catch { stop(error) }
    }
    override func broadcastPaused() { do { try recording?.pause() } catch { stop(error) } }
    override func broadcastResumed() { do { try recording?.resume() } catch { stop(error) } }
    override func broadcastFinished() { try? recording?.finish(); recording = nil }
    private func stop(_ error: Error) {
        try? recording?.finish(state: .interrupted,reason: .failed); recording = nil
        finishBroadcastWithError(error as NSError)
    }
}
