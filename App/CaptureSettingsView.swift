import SwiftUI

struct CaptureSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var enabled = true
    @State private var seconds = "3"
    @State private var saved = false
    @FocusState private var editingSeconds: Bool
    var body: some View {
        VStack(alignment: .leading,spacing: 12) {
            Toggle("停滑后自动停止录屏",isOn: $enabled).font(.headline)
            HStack {
                Text("停止前等待")
                Spacer()
                TextField("秒数",text: $seconds).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .frame(width: 100).textFieldStyle(.roundedBorder).focused($editingSeconds)
                    .accessibilityIdentifier("settings.idle.seconds").disabled(!enabled)
                Text("秒")
                Button("保存设置") {
                    if model.saveCapturePreferences(enabled: enabled,seconds: seconds) {saved = true;editingSeconds = false}
                }.buttonStyle(.bordered).accessibilityIdentifier("settings.save")
            }.font(.subheadline)
            Text(saved ? "已保存，下次录屏生效。" : "支持任意正数和小数。首次识别到画面滚动后开始计时，修改在下次录屏生效。")
                .font(.caption).foregroundStyle(saved ? Color.green : Color.secondary)
        }.padding(18).background(.background,in: RoundedRectangle(cornerRadius: 22)).disabled(!model.captureReady)
        .onAppear {enabled = model.capturePreferences.idleStopEnabled;seconds = String(model.capturePreferences.idleSeconds)}
        .onChange(of: enabled) {_,_ in saved = false}
        .onChange(of: seconds) {_,_ in saved = false}
        .onChange(of: scenePhase) {_,phase in if phase != .active {editingSeconds = false}}
    }
}
