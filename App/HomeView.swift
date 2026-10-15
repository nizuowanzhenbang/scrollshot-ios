import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import ScrollShotCore

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showFiles = false
    @State private var showPhotos = false
    @State private var movie: PhotosPickerItem?
    @State private var loadingMovie = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading,spacing: 22) {
                    HStack(spacing: 14) {
                        Image(systemName: "rectangle.stack.fill").font(.system(size: 37)).foregroundStyle(.tint)
                        VStack(alignment: .leading,spacing: 5) {
                            Text("把滚动，留成一张图").font(.title2.bold())
                            Text("本机处理 · 原尺寸输出").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical,10)
                    #if !IMPORT_ONLY
                    HStack(spacing: 16) {
                        if model.captureReady,let identifier = model.captureExtensionIdentifier { BroadcastButton(extensionIdentifier: identifier).frame(width: 60,height: 60).disabled(model.busy) }
                        else { Image(systemName: "exclamationmark.circle").font(.largeTitle).foregroundStyle(.orange) }
                        VStack(alignment: .leading,spacing: 6) {
                            Text(model.captureReady ? "开始滚动截图" : "共享权限需要检查").font(.headline)
                            Text(model.captureExplanation).font(.caption).foregroundStyle(.secondary)
                            Button("采集检查"){model.message = model.captureDiagnostics}.font(.caption)
                        }
                    }.padding(18).background(.background,in: RoundedRectangle(cornerRadius: 22))
                    CaptureSettingsView()
                    #endif
                    VStack(alignment: .leading,spacing: 13) {
                        Label("已有录屏？直接生成长图",systemImage: "film.stack").font(.headline)
                        Text("使用系统录屏记录竖向匀速滚动，再从相册或文件选择视频。采集时避免一次跳过整屏内容。").font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            Button {showPhotos = true} label: { Label("从相册选择",systemImage: "photo.on.rectangle") }.buttonStyle(.borderedProminent)
                            Button {showFiles = true} label: {Label("文件",systemImage: "folder")}.buttonStyle(.bordered).accessibilityIdentifier("home.import.files")
                        }.disabled(model.busy || loadingMovie)
                        if loadingMovie { ProgressView("正在读取所选视频…").font(.caption) }
                    }.padding(18).background(.background,in: RoundedRectangle(cornerRadius: 22))
                    HStack { Text("草稿与作品").font(.title3.bold()); Spacer(); Text("\(model.sessions.count)").foregroundStyle(.secondary) }
                    if model.sessions.isEmpty {
                        ContentUnavailableView("还没有截图",systemImage: "rectangle.stack.badge.plus",description: Text("开始一次采集，或导入一段录屏。"))
                    }
                    ForEach(model.sessions) { session in
                        Button {model.openSession(session)} label: {
                            HStack(spacing: 14) {
                                Image(systemName: session.outputs.isEmpty ? "square.stack.3d.up" : "checkmark.rectangle.stack").font(.title2).frame(width: 36)
                                VStack(alignment: .leading,spacing: 4) {
                                    Text(session.createdAt.formatted(date: .abbreviated,time: .shortened)).font(.headline).foregroundStyle(.primary)
                                    Text("\(session.frames.count) 帧 · "+(session.outputs.isEmpty ? "草稿" : "\(session.outputs.count) 张长图")).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }.padding(16).background(.background,in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain)
                    }
                    Text("轻卷截图 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2") · 本机处理")
                        .font(.caption2).foregroundStyle(.secondary).padding(.top,6)
                }.padding(20)
            }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("轻卷截图")
            .toolbar {Button {model.refreshAndProcess()} label: {Image(systemName: "arrow.clockwise")}.disabled(model.busy)}
            .safeAreaInset(edge: .bottom) { if model.busy { WorkProgress() } }
            .fullScreenCover(item: $model.destination) { destination in
                switch destination {
                case .editor(let session):NavigationStack {SessionView(session: session).environmentObject(model)}
                case .result(let session):LongScreenshotView(session: session).environmentObject(model).id(session.id)
                }
            }
            .photosPicker(isPresented: $showPhotos,selection: $movie,matching: .videos)
            .fileImporter(isPresented: $showFiles,allowedContentTypes: [.movie]) { result in
                switch result {case .success(let url): model.importVideo(url); case .failure(let error): model.message = error.localizedDescription}
            }
            .onChange(of: movie) { _,item in
                guard let item else { return }; loadingMovie = true
                Task {
                    do {
                        guard let value = try await item.loadTransferable(type: ImportedMovie.self) else { throw ScrollShotError.io("无法读取所选录屏") }
                        model.importVideo(value.url,removeAfter: true)
                    } catch {model.message = error.localizedDescription}
                    loadingMovie = false; movie = nil
                }
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else {return}
                var quietPolls = 0
                while !Task.isCancelled {
                    if !showFiles && !showPhotos && !loadingMovie {model.refreshAndProcess()}
                    quietPolls = model.hasActiveCapture || model.busy ? 0 : quietPolls+1
                    if quietPolls >= 15 {return}
                    do {try await Task.sleep(for: .seconds(1))} catch {return}
                }
            }
            .alert("轻卷截图",isPresented: Binding(get: {model.message != nil && model.destination?.id == nil},set: {if !$0 {model.message = nil}})) {Button("知道了"){model.message = nil}} message: {Text(model.message ?? "")}
        }
    }
}
struct WorkProgress: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(spacing: 8) {
            HStack { Text(model.phase).font(.subheadline.bold()); Spacer(); Text("\(Int(model.progress*100))%").monospacedDigit(); Button("取消"){model.cancel()} }
            ProgressView(value: model.progress)
        }.padding(18).background(.regularMaterial)
    }
}
