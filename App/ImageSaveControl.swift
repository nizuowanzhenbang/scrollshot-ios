import SwiftUI
import ScrollShotCore
struct ImageSaveControl:View {
    @EnvironmentObject private var model:AppModel
    let session:SessionManifest
    var floating=true
    @Binding var compressRequested:Bool
    @State private var saving=false
    @State private var saved=false
    @State private var choice=false
    private var current:SessionManifest {model.sessions.first{$0.id==session.id} ?? session}
    var body:some View {
        Button(action:save) {
            if floating {
                Group {if saving {ProgressView().tint(.white)} else {Image(systemName:saved ? "checkmark":"square.and.arrow.down").font(.title3.bold())}}
                    .frame(width:54,height:54).foregroundStyle(.white).background(.blue,in:Circle()).shadow(color:.black.opacity(0.35),radius:8,y:3)
            } else {Label(saving ? "保存中":"保存相册",systemImage:"square.and.arrow.down")}
        }.disabled(saving || model.busy || model.savingPhotos || model.outputURLs(current).isEmpty)
            .accessibilityLabel("保存到相册").accessibilityIdentifier(floating ? "result.save":"editor.save")
            .overlay(alignment:.topTrailing) {
                if saved {Text("已保存到相册").font(.subheadline.bold()).fixedSize().padding(.horizontal,18).padding(.vertical,12).background(.regularMaterial,in:Capsule()).offset(y:-62).accessibilityIdentifier("result.saved")}
            }
            .task(id:saved) {if saved {try? await Task.sleep(for:.seconds(3));if !Task.isCancelled {saved=false}}}
            .onChange(of:compressRequested) {_,value in if value {compressRequested=false;compress(andSave:false)}}
            .confirmationDialog("图片共 \(size(model.outputURLs(current)))，选择保存方式",isPresented:$choice,titleVisibility:.visible) {
                Button("保存原始 PNG"){saveFiles(model.outputURLs(current))}
                if !model.outputURLs(current,compressed:true).isEmpty {Button("保存压缩 JPEG（\(size(model.outputURLs(current,compressed:true)))）"){saveFiles(model.outputURLs(current,compressed:true))}}
                else {Button("压缩后保存（JPEG，超长分图）"){compress(andSave:true)}}
                Button("取消",role:.cancel){}
            }
    }
    private func bytes(_ urls:[URL])->Double {urls.reduce(0){$0+Double((try? $1.resourceValues(forKeys:[.fileSizeKey]).fileSize) ?? 0)}}
    private func size(_ urls:[URL])->String {ByteCountFormatter.string(fromByteCount:Int64(bytes(urls)),countStyle:.file)}
    @MainActor private func save() {
        let urls=model.outputURLs(current)
        guard !saving,!urls.isEmpty else {return}
        if bytes(urls)>model.toolPreferences.compressionPromptMB*1024*1024 || !model.outputURLs(current,compressed:true).isEmpty {choice=true} else {saveFiles(urls)}
    }
    @MainActor private func compress(andSave:Bool) {
        model.compress(current.id) {ok in guard ok else {return};if andSave {saveFiles(model.outputURLs(current,compressed:true))} else {choice=true}}
    }
    @MainActor private func saveFiles(_ urls:[URL]) {
        guard !saving,!model.savingPhotos,!urls.isEmpty else {return};saving=true;model.savingPhotos=true
        Task {do {try await PhotoSaver.save(urls);saved=true} catch {model.message=error.localizedDescription};saving=false;model.savingPhotos=false}
    }
}
