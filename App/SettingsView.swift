import SwiftUI
import ScrollShotCore
struct SettingsView:View {
    @EnvironmentObject private var model:AppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance=0
    @State private var threshold="20"
    @State private var saved=false
    var body:some View {
        NavigationStack {
            Form {
                Section("外观") {
                    Picker("显示模式",selection:$appearance) {Text("自动").tag(0);Text("浅色").tag(1);Text("深色").tag(2)}.pickerStyle(.segmented).accessibilityIdentifier("settings.appearance")
                    Text("自动模式跟随系统切换深色或浅色。 ").font(.caption).foregroundStyle(.secondary)
                }
                #if !IMPORT_ONLY
                Section("滚动采集") {CaptureSettingsView();Button("采集检查"){model.message=model.captureDiagnostics}}
                #endif
                Section {
                    Toggle("智能去除滚动条",isOn:Binding(get:{model.toolPreferences.smartScrollbar},set:{v in var p=model.toolPreferences;p.smartScrollbar=v;model.saveTools(p)})).accessibilityIdentifier("settings.scrollbar")
                    Text("生成长图时识别右侧窄滚动条并填补对应区域。关闭后保留原画面；修改后需重新生成已有作品。复杂背景可能无法可靠识别。 ").font(.caption).foregroundStyle(.secondary)
                    Toggle("开始和停止时震动",isOn:Binding(get:{model.toolPreferences.haptics},set:{v in var p=model.toolPreferences;p.haptics=v;model.saveTools(p)}))
                    Text("录屏扩展请求系统震动；实际反馈受 iOS 后台策略及系统触感设置影响。下次录屏生效。 ").font(.caption).foregroundStyle(.secondary)
                } header:{Text("采集与图像")}
                Section("大图压缩提醒") {
                    HStack {Text("超过");TextField("大小",text:$threshold).keyboardType(.decimalPad).multilineTextAlignment(.trailing).accessibilityIdentifier("settings.compression.mb");Text("MB 时询问")}
                    Button(saved ? "已保存":"保存提醒大小") {var p=model.toolPreferences;p.compressionPromptMB=Double(threshold.replacingOccurrences(of:",",with:".")) ?? .nan;saved=model.saveTools(p)}.accessibilityIdentifier("settings.compression.save")
                    Text("默认 20 MB。保存时可选原图或压缩 JPEG；超长图片会分图，原始 PNG 保留。 ").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
                .toolbar {Button("完成"){dismiss()}.accessibilityIdentifier("settings.done")}
                .onAppear {threshold=String(model.toolPreferences.compressionPromptMB)}
                .onChange(of:threshold) {_,_ in saved=false}
                .alert("轻卷截图",isPresented:Binding(get:{model.message != nil},set:{if !$0 {model.message=nil}})) {Button("知道了"){model.message=nil}} message:{Text(model.message ?? "")}
        }
    }
}
