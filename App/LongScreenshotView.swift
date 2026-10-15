import SwiftUI
import ScrollShotCore

struct LongScreenshotView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let session: SessionManifest
    @State private var editing = false
    @State private var imageEditing=false
    @State private var compressRequested=false
    private struct Row: Identifiable {
        let id: String
        let width: Int
        let piece: ImagePiece
    }
    private var current: SessionManifest {model.sessions.first {$0.id == session.id} ?? session}
    private var rows: [Row] {
        let value = current
        if let tiles=value.renderedTiles,!tiles.isEmpty {
            return tiles.enumerated().map {index,tile in Row(id:"tile-\(index)-\(tile.fileName)",width:tile.width,piece:ImagePiece(fileName:tile.fileName,sourceY:0,height:tile.height,destinationY:tile.offsetY))}
        }
        let records = value.previewFrames.isEmpty ? value.frames : value.previewFrames
        guard let segments = try? StitchPlanner.build(records: records,crop: value.crop),
              let pages = try? StitchPlanner.pages(segments: segments,outer: value.outerCrop) else {return []}
        return pages.enumerated().flatMap { page,segment in
            segment.pieces.enumerated().map { index,piece in Row(id: "\(page)-\(index)",width: segment.width,piece: piece) }
        }
    }
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !current.outputs.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) {row in
                            PieceThumbnail(url: model.store.directory(for: current.id).appendingPathComponent(row.piece.fileName),piece: row.piece,width: row.width,maxPixelSize: 3000)
                        }
                    }.padding(.top,64).padding(.bottom,88)
                }.accessibilityIdentifier("result.preview")
            } else if model.busy {
                VStack(spacing: 16) {
                    ProgressView().tint(.white)
                    Text(model.phase).font(.headline)
                    ProgressView(value: model.progress).tint(.white).frame(maxWidth: 220)
                    Button("取消生成"){model.cancel()}.buttonStyle(.bordered)
                }
            } else {
                ContentUnavailableView {
                    Label("尚未生成长截图",systemImage: "rectangle.stack")
                } description: {
                    Text("原始草稿仍在，可以重新生成。")
                } actions: {
                    Button("重新生成"){model.export(current.id,crop: current.crop,outer: current.outerCrop)}.buttonStyle(.borderedProminent)
                }
            }
        }.foregroundStyle(.white).statusBarHidden()
        .overlay(alignment: .top) {
            HStack {
                Button {dismiss()} label: {Image(systemName: "xmark").frame(width: 44,height: 44).background(.ultraThinMaterial,in: Circle())}
                    .accessibilityLabel("关闭全屏预览").accessibilityIdentifier("result.close")
                Spacer()
                Menu {
                    Button("马赛克与裁剪",systemImage:"square.on.square"){imageEditing=true}.accessibilityIdentifier("tools.image")
                    Button("压缩图片",systemImage:"arrow.down.right.and.arrow.up.left"){compressRequested=true}.disabled(model.busy)
                    Button("调整拼接与分享",systemImage:"slider.horizontal.3"){editing=true}
                } label:{Text("工具").font(.subheadline.bold()).padding(.horizontal,18).frame(height:44).background(.ultraThinMaterial,in:Capsule())}.accessibilityIdentifier("result.tools").disabled(model.busy || model.savingPhotos || current.outputs.isEmpty)
            }.foregroundStyle(.white).padding(.horizontal,18).padding(.top,10)
        }
        .overlay(alignment: .bottomTrailing) {
            ImageSaveControl(session:current,compressRequested:$compressRequested).padding(20)
        }
        .onAppear {model.markResultPresented(session)}
        .sheet(isPresented: $editing) {NavigationStack {SessionView(session: current).environmentObject(model)}.foregroundStyle(.primary)}
        .sheet(isPresented:$imageEditing) {ImageEditorView(session:current).environmentObject(model).foregroundStyle(.primary)}
        .overlay(alignment:.bottom) {if model.busy && !current.outputs.isEmpty {WorkProgress().padding(.bottom,84)}}
        .alert("轻卷截图",isPresented: Binding(get: {model.message != nil && !editing && !imageEditing},set: {if !$0 {model.message = nil}})) {Button("知道了"){model.message = nil}} message: {Text(model.message ?? "")}
    }
}
