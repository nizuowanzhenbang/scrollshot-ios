import Foundation
import AVFoundation
import CoreImage
public enum ImportService {
    public static func importVideo(url: URL,store: SessionStore,progress: @escaping (Double)->Void) async throws -> SessionManifest {
        let pipeline = try CapturePipeline(store: store)
        let local = store.directory(for: pipeline.manifest.id).appendingPathComponent("import-"+UUID().uuidString+".mov")
        do {
            try FileManager.default.copyItem(at: url,to: local)
            defer { try? FileManager.default.removeItem(at: local) }
            let asset = AVURLAsset(url: local)
            guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ScrollShotError.invalidInput("所选文件没有视频轨道") }
            let transform = try await track.load(.preferredTransform)
            let duration = try await asset.load(.duration).seconds
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track,outputSettings: [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA])
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else { throw ScrollShotError.unavailable("无法解码所选视频") }
            reader.add(output)
            guard reader.startReading() else { throw reader.error ?? ScrollShotError.io("视频读取失败") }
            while let sample = output.copyNextSampleBuffer() {
                if Task.isCancelled { reader.cancelReading(); throw CancellationError() }
                try autoreleasepool {
                    guard let buffer = CMSampleBufferGetImageBuffer(sample) else { return }
                    let seconds = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                    try pipeline.process(image: CIImage(cvPixelBuffer: buffer).transformed(by: transform),timestamp: seconds)
                    progress(min(0.99,max(0,seconds/max(1,duration))))
                }
            }
            if reader.status == .failed { throw reader.error ?? ScrollShotError.io("视频解码中断") }
            try pipeline.finish()
            guard !pipeline.manifest.frames.isEmpty else { throw ScrollShotError.invalidInput("没有采集到有效画面") }
            progress(1); return pipeline.manifest
        } catch {
            try? pipeline.finish(state: .interrupted)
            try? FileManager.default.removeItem(at: local)
            throw error
        }
    }
}
