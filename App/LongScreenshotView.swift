import SwiftUI
import ScrollShotCore

struct LongScreenshotView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let session: SessionManifest
    @State private var editing = false
    @State private var saving = false
    @State private var saved = false
    private struct Row: Identifiable {
        let id: String
        let width: Int
        let piece: ImagePiece
    }
    private var current: SessionManifest {model.sessions.first {$0.id == session.id} ?? session}
    private var rows: [Row] {
        let value = current
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
                Button("调整"){editing = true}.font(.subheadline.bold()).padding(.horizontal,18).frame(height: 44).background(.ultraThinMaterial,in: Capsule())
            }.foregroundStyle(.white).padding(.horizontal,18).padding(.top,10)
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: save) {
                Group {
                    if saving {ProgressView().tint(.white)}
                    else {Image(systemName: saved ? "checkmark" : "square.and.arrow.down").font(.title3.bold())}
                }.frame(width: 54,height: 54).background(.blue,in: Circle()).shadow(color: .black.opacity(0.35),radius: 8,y: 3)
            }.foregroundStyle(.white).padding(20)
                .disabled(saving || model.busy || model.outputURLs(current).isEmpty)
                .accessibilityLabel("保存到相册").accessibilityIdentifier("result.save")
        }
        .overlay(alignment: .bottom) {
            if saved {Text("已保存到相册").font(.subheadline.bold()).padding(.horizontal,18).padding(.vertical,12).background(.ultraThinMaterial,in: Capsule()).padding(.bottom,90).accessibilityIdentifier("result.saved")}
        }
        .onAppear {model.markResultPresented(session)}
        .task(id: saved) {if saved {try? await Task.sleep(for: .seconds(3));if !Task.isCancelled {saved = false}}}
        .sheet(isPresented: $editing) {NavigationStack {SessionView(session: current).environmentObject(model)}.foregroundStyle(.primary)}
        .alert("轻卷截图",isPresented: Binding(get: {model.message != nil && !editing},set: {if !$0 {model.message = nil}})) {Button("知道了"){model.message = nil}} message: {Text(model.message ?? "")}
    }
    @MainActor private func save() {
        guard !saving else {return}
        let urls = model.outputURLs(current)
        guard !urls.isEmpty else {return}
        saving = true
        Task {
            do {try await PhotoSaver.save(urls);saved = true}
            catch {model.message = error.localizedDescription}
            saving = false
        }
    }
}
