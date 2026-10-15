import SwiftUI
import UIKit
import Photos
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers
import ImageIO
import ScrollShotCore
#if !IMPORT_ONLY
import ReplayKit
struct BroadcastButton: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let view = RPSystemBroadcastPickerView(frame: CGRect(x: 0,y: 0,width: 60,height: 60))
        view.preferredExtension = Bundle.main.object(forInfoDictionaryKey: "BroadcastExtensionIdentifier") as? String
        view.showsMicrophoneButton = false
        return view
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView,context: Context) {}
}
#endif
struct ImportedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in SentTransferredFile(movie.url) } importing: { received in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("selected-"+UUID().uuidString+"."+received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file,to: url)
            return ImportedMovie(url: url)
        }
    }
}
struct ShareFiles: UIViewControllerRepresentable {
    let urls: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: urls,applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController,context: Context) {}
}
enum PhotoSaver {
    static func save(_ urls: [URL]) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw ScrollShotError.unavailable("相册添加权限未开启，仍可通过分享保存文件。") }
        try await PHPhotoLibrary.shared().performChanges {
            for url in urls { PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url) }
        }
    }
}
struct PieceThumbnail: View {
    let url: URL
    let piece: ImagePiece
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { ProgressView().frame(height: 80) }
        }.task(id: url.path+"-\(piece.sourceY)-\(piece.height)") {
            image = await Task.detached(priority: .utility) {
                guard let source = CGImageSourceCreateWithURL(url as CFURL,nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:900,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary),
                      let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],let originalHeight = properties[kCGImagePropertyPixelHeight] as? Int else { return nil as UIImage? }
                let scale = Double(thumbnail.height)/Double(originalHeight)
                let rect = CGRect(x: 0,y: Double(piece.sourceY)*scale,width: Double(thumbnail.width),height: Double(piece.height)*scale).integral
                guard let cut = thumbnail.cropping(to: rect) else { return nil }
                return UIImage(cgImage: cut)
            }.value
        }
    }
}
