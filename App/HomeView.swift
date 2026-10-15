import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import ScrollShotCore
struct HomeView:View {
    @EnvironmentObject private var model:AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showFiles=false
    @State private var showPhotos=false
    @State private var showSettings=false
    @State private var loadingMovie=false
    @State private var movie:PhotosPickerItem?
    @State private var deleting:SessionManifest?
    var body:some View {
        NavigationStack {
            List {
                Section {
                    if model.sessions.isEmpty {ContentUnavailableView("还没有截图",systemImage:"rectangle.stack.badge.plus",description:Text("开始采集，或导入一段录屏。"))}
                    ForEach(Array(model.sessions.prefix(5))) {session in DraftRow(session:session,requestDelete:{deleting=$0})}
                    if model.sessions.count>5 {NavigationLink {DraftLibraryView()} label:{Label("更多草稿（全部 \(model.sessions.count) 个）",systemImage:"tray.full")}.accessibilityIdentifier("library.more")}
                } header:{HStack {Text("草稿与作品");Spacer();Text("\(model.sessions.count)")}}
                #if !IMPORT_ONLY
                Section {
                    HStack(spacing:16) {
                        if model.captureReady,let identifier=model.captureExtensionIdentifier {BroadcastButton(extensionIdentifier:identifier).frame(width:60,height:60).disabled(model.busy)}
                        else {Image(systemName:"exclamationmark.circle").font(.largeTitle).foregroundStyle(.orange)}
                        VStack(alignment:.leading,spacing:6) {Text(model.captureReady ? "开始滚动截图":"共享权限需要检查").font(.headline);Text(model.captureExplanation).font(.caption).foregroundStyle(.secondary)}
                    }.padding(.vertical,8)
                }
                #endif
                Section {
                    VStack(alignment:.leading,spacing:13) {
                        Label("已有录屏？直接生成长图",systemImage:"film.stack").font(.headline)
                        Text("系统录屏时竖向匀速滚动，再从相册或文件选择视频。 ").font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            Button {showPhotos=true} label:{Label("从相册选择",systemImage:"photo.on.rectangle")}.buttonStyle(.borderedProminent)
                            Button {showFiles=true} label:{Label("文件",systemImage:"folder")}.buttonStyle(.bordered).accessibilityIdentifier("home.import.files")
                        }.disabled(model.busy || loadingMovie)
                        if loadingMovie {ProgressView("正在读取视频…")}
                    }.padding(.vertical,8)
                } footer:{Text("轻卷截图 \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "0.3") · 本机处理")}
            }.navigationTitle("轻卷截图")
                .toolbar {
                    Button {model.refreshAndProcess()} label:{Image(systemName:"arrow.clockwise")}.disabled(model.busy).accessibilityLabel("刷新")
                    Button {showSettings=true} label:{Image(systemName:"gearshape")}.accessibilityLabel("设置").accessibilityIdentifier("home.settings")
                }
                .safeAreaInset(edge:.bottom) {if model.busy {WorkProgress()}}
                .sheet(isPresented:$showSettings,onDismiss:{model.refreshAndProcess()}) {SettingsView().environmentObject(model)}
                .fullScreenCover(item:$model.destination) {destination in
                    switch destination {
                    case .editor(let session):NavigationStack {SessionView(session:session).environmentObject(model)}
                    case .result(let session):LongScreenshotView(session:session).environmentObject(model).id(session.id)
                    }
                }
                .confirmationDialog("删除草稿及作品？原始帧和导出图片都会删除。",isPresented:Binding(get:{deleting != nil},set:{if !$0 {deleting=nil}}),titleVisibility:.visible) {
                    Button("删除",role:.destructive){if let value=deleting {model.delete(value)};deleting=nil}.accessibilityIdentifier("library.confirm.delete")
                    Button("取消",role:.cancel){deleting=nil}
                }
                .photosPicker(isPresented:$showPhotos,selection:$movie,matching:.videos)
                .fileImporter(isPresented:$showFiles,allowedContentTypes:[.movie]) {result in
                    switch result {case .success(let url):model.importVideo(url);case .failure(let error):model.message=error.localizedDescription}
                }
                .onChange(of:movie) {_,item in
                    guard let item else {return};loadingMovie=true
                    Task {
                        do {guard let value=try await item.loadTransferable(type:ImportedMovie.self) else {throw ScrollShotError.io("无法读取视频")};model.importVideo(value.url,removeAfter:true)}
                        catch {model.message=error.localizedDescription}
                        loadingMovie=false;movie=nil
                    }
                }
                .task(id:scenePhase) {
                    guard scenePhase == .active else {return}
                    var quiet=0
                    while !Task.isCancelled {
                        if !showFiles && !showPhotos && !loadingMovie && !showSettings && deleting==nil {model.refreshAndProcess()}
                        quiet=model.hasActiveCapture || model.busy ? 0:quiet+1
                        if quiet>=15 {return}
                        do {try await Task.sleep(for:.seconds(1))} catch {return}
                    }
                }
                .alert("轻卷截图",isPresented:Binding(get:{model.message != nil && model.destination?.id == nil && !showSettings},set:{if !$0 {model.message=nil}})) {Button("知道了"){model.message=nil}} message:{Text(model.message ?? "")}
        }
    }
}
struct WorkProgress:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        VStack(spacing:8) {
            HStack {Text(model.phase).font(.subheadline.bold());Spacer();Text("\(Int(model.progress*100))%").monospacedDigit();Button("取消"){model.cancel()}}
            ProgressView(value:model.progress)
        }.padding(18).background(.regularMaterial)
    }
}
