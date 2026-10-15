import SwiftUI
import ScrollShotCore

struct SessionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let session: SessionManifest
    @State private var top = 0
    @State private var bottom = 0
    @State private var finalTop = 0
    @State private var finalBottom = 0
    @State private var sharing = false
    @State private var saving = false
    @State private var imageEditing=false
    private var current: SessionManifest {model.sessions.first(where: {$0.id == session.id}) ?? session}
    private var segments: [StitchSegment] { (try? StitchPlanner.build(records: current.previewFrames.isEmpty ? current.frames : current.previewFrames,crop: CropInsets(top: top,bottom: bottom))) ?? [] }
    private enum PreviewRow: Identifiable {
        case heading(Int,Int,Int), piece(Int,Int,ImagePiece,Int)
        var id: String { switch self { case .heading(let i,_,_): return "header-\(i)"; case .piece(let i,let j,_,_): return "piece-\(i)-\(j)" } }
    }
    private var previewRows: [PreviewRow] {
        segments.enumerated().flatMap { index,segment in
            [PreviewRow.heading(index,segment.width,segment.height)] + segment.pieces.enumerated().map { PreviewRow.piece(index,$0.offset,$0.element,segment.width) }
        }
    }
    private var limit: Int {min(800,max(1,(current.frames.first?.height ?? 600)/3))}
    var body: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 20) {
                if current.state == .recording || current.state == .paused {
                    VStack(alignment: .leading,spacing: 8) {
                        Text("请先停止系统录屏").font(.headline)
                        Text("如果采集异常中断，可在停止更新 10 秒后恢复草稿。").font(.caption).foregroundStyle(.secondary)
                        Button("恢复已中断的草稿"){model.recover(current)}
                    }
                }
                VStack(alignment: .leading,spacing: 12) {
                    Text("去除每帧的固定顶栏 / 底栏").font(.headline)
                    Text("初始范围为建议值；可调至 0 保留完整画面。修改后重新生成，原始采集帧会保留。").font(.caption).foregroundStyle(.secondary)
                    cropSlider("顶部",value: $top,max: limit)
                    cropSlider("底部",value: $bottom,max: limit)
                    DisclosureGroup("最终图像边界裁剪（每个片段）") {
                        cropSlider("上边界",value: $finalTop,max: 800)
                        cropSlider("下边界",value: $finalBottom,max: 800)
                    }.font(.subheadline)
                    if current.pageEdits?.contains(where:{$0.crop != nil || !$0.mosaics.isEmpty}) == true {Text("重新拼接会清除图片裁剪和马赛克；请在最终拼接后再编辑图片。 ").font(.caption).foregroundStyle(.orange)}
                    Button {model.export(current.id,crop: CropInsets(top: top,bottom: bottom),outer: CropInsets(top: finalTop,bottom: finalBottom))} label: {
                        Label(current.outputs.isEmpty ? "生成长截图" : "按当前范围重新生成",systemImage: "rectangle.stack.badge.plus").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).disabled(model.busy || model.savingPhotos || current.frames.isEmpty || current.state == .recording || current.state == .paused)
                }.padding(16).background(.background,in: RoundedRectangle(cornerRadius: 18))
                if !current.outputs.isEmpty {
                    Button("马赛克与裁剪图片"){imageEditing=true}.buttonStyle(.bordered).disabled(model.busy || model.savingPhotos)
                    HStack {
                        Button {sharing = true} label: {Label("分享文件",systemImage: "square.and.arrow.up")}.buttonStyle(.borderedProminent)
                        ImageSaveControl(session:current,floating:false,compressRequested:.constant(false)).buttonStyle(.bordered)
                    }.disabled(saving || model.busy)
                    Text("已生成 \(current.outputs.count) 张 PNG。超长内容和不连续画面会分别输出。").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(current.warnings,id: \.self) {Text($0).font(.caption).foregroundStyle(.orange)}
                HStack {Text("原始拼接预览").font(.headline); Spacer(); Text("\(current.frames.count) 帧").font(.caption).foregroundStyle(.secondary)}
                LazyVStack(spacing: 0) {
                    ForEach(previewRows) { row in
                        switch row {
                        case .heading(let index,let width,let height):
                            HStack {Text("片段 \(index+1)"); Spacer(); Text("\(width) × \(height)")}.font(.caption.monospacedDigit()).foregroundStyle(.secondary).padding(.vertical,12)
                        case .piece(_,_,let piece,let width):
                            PieceThumbnail(url: model.store.directory(for: current.id).appendingPathComponent(piece.fileName),piece: piece,width: width)
                        }
                    }
                }
                Text("此处显示原始拼接素材，不含图片马赛克。请在全屏结果查看最终裁剪、马赛克及滚动条处理；保存与分享使用实际生成文件。")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(18)
        }.background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("编辑与结果").navigationBarTitleDisplayMode(.inline)
        .toolbar {Button("关闭"){dismiss()}}
        .safeAreaInset(edge: .bottom) {if model.busy {WorkProgress()}}
        .sheet(isPresented: $sharing) {ShareFiles(urls: model.outputURLs(current))}
        .sheet(isPresented:$imageEditing) {ImageEditorView(session:current).environmentObject(model)}
        .onAppear {top = current.crop.top; bottom = current.crop.bottom; finalTop = current.outerCrop.top; finalBottom = current.outerCrop.bottom}
        .alert("轻卷截图",isPresented: Binding(get: {model.message != nil},set: {if !$0 {model.message = nil}})) {Button("知道了"){model.message = nil}} message: {Text(model.message ?? "")}
    }
    private func cropSlider(_ label: String,value: Binding<Int>,max: Int) -> some View {
        VStack(spacing: 2) {
            HStack {Text(label); Spacer(); Text("\(value.wrappedValue) px").monospacedDigit().foregroundStyle(.secondary)}.font(.caption)
            Slider(value: Binding(get: {Double(value.wrappedValue)},set: {value.wrappedValue = Int($0)}),in: 0...Double(max),step: 1)
        }
    }
}
