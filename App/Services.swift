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
    let extensionIdentifier: String
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let view = RPSystemBroadcastPickerView(frame: CGRect(x: 0,y: 0,width: 60,height: 60))
        view.preferredExtension = extensionIdentifier
        view.showsMicrophoneButton = false
        return view
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView,context: Context) {uiView.preferredExtension = extensionIdentifier}
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
    let width: Int
    var maxPixelSize: Int = 900
    @State private var image: UIImage?
    var body: some View {
        Color.clear.aspectRatio(CGFloat(width)/CGFloat(max(1,piece.height)),contentMode: .fit)
            .overlay {
                if let image { Image(uiImage: image).resizable().scaledToFit() }
                else { ProgressView() }
            }.task(id: url.path+"-\(piece.sourceY)-\(piece.height)-\(maxPixelSize)") {
                image = nil
                do {
                    let decoded = try await ThumbnailDecoder.shared.decode(url: url,sourceY: piece.sourceY,height: piece.height,maxPixelSize: maxPixelSize)
                    try Task.checkCancellation()
                    image = UIImage(cgImage: decoded)
                } catch { image = nil }
            }.onDisappear {image = nil}
    }
}
