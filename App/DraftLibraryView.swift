import SwiftUI
import ScrollShotCore
struct DraftRow:View {
    @EnvironmentObject private var model:AppModel
    let session:SessionManifest
    let requestDelete:(SessionManifest)->Void
    var body:some View {
        Button {model.openSession(session)} label:{
            HStack(spacing:14) {
                Image(systemName:session.outputs.isEmpty ? "square.stack.3d.up":"checkmark.rectangle.stack").font(.title2).frame(width:32)
                VStack(alignment:.leading,spacing:4) {
                    Text(session.createdAt.formatted(date:.abbreviated,time:.shortened)).font(.headline).foregroundStyle(.primary)
                    Text("\(session.frames.count) 帧 · "+(session.outputs.isEmpty ? "草稿":"\(session.outputs.count) 张长图")).font(.caption).foregroundStyle(.secondary)
                };Spacer();Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical,6)
        }.accessibilityIdentifier("library.open")
            .swipeActions(edge:.leading,allowsFullSwipe:false) {Button(role:.destructive){requestDelete(session)} label:{Label("删除",systemImage:"trash")}.accessibilityIdentifier("library.delete").disabled(model.busy || model.savingPhotos || session.state == .recording || session.state == .paused)}
    }
}
struct DraftLibraryView:View {
    @EnvironmentObject private var model:AppModel
    @State private var deleting:SessionManifest?
    var body:some View {
        List {ForEach(model.sessions) {session in DraftRow(session:session,requestDelete:{deleting=$0})}}
            .navigationTitle("全部草稿与作品")
            .confirmationDialog("删除草稿及作品？原始帧和导出图片都会删除。",isPresented:Binding(get:{deleting != nil},set:{if !$0 {deleting=nil}}),titleVisibility:.visible) {
                Button("删除",role:.destructive){if let value=deleting {model.delete(value)};deleting=nil}.accessibilityIdentifier("library.confirm.delete")
                Button("取消",role:.cancel){deleting=nil}
            }
    }
}
