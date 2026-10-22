import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import ScrollShotCore

@MainActor final class AppModel: ObservableObject {
    @Published var sessions: [SessionManifest] = []
    @Published var destination: SessionDestination?
    @Published var capturePreferences = CapturePreferences()
    @Published var toolPreferences = ToolPreferences()
    @Published var busy = false
    @Published var savingPhotos=false
    @Published var progress = 0.0
    @Published var phase = ""
    @Published var message: String?
    let store: SessionStore
    let captureReady: Bool
    let captureExplanation: String
    let captureExtensionIdentifier: String?
    let captureDiagnostics: String
    private var operation: Task<Void,Never>?
    private var lastPresentedDate = Date.distantPast
    init() {
        let documents = FileManager.default.urls(for: .documentDirectory,in: .userDomainMask)[0]
        var root = documents.appendingPathComponent("Drafts",isDirectory: true)
        var ready = false,explanation = "从相册或文件导入系统录屏，在本机生成长图。",diagnostics = "导入版不包含录屏扩展。"
        #if IMPORT_ONLY
        captureExtensionIdentifier = nil
        #else
        let access = CaptureAccess.inspect(bundleURL: Bundle.main.bundleURL) {FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)}
        captureExtensionIdentifier = access.extensionIdentifier;diagnostics = access.diagnostics
        if let container = access.container {
            root = container.drafts;ready = true
            explanation = "点击录屏按钮，按系统提示开始后切到目标 App 匀速滚动；停止后返回。"
        } else {
            explanation = access.extensionIdentifier == nil ? "录屏扩展缺失。请在全能签中保留插件并重新签名。" : "共享权限自检未通过。请查看采集检查，或先导入系统录屏。"
        }
        #endif
        do { store = try SessionStore(root: root) }
        catch {
            // A writable app-local fallback keeps imported drafts usable.
            store = try! SessionStore(root: documents.appendingPathComponent("LocalDrafts",isDirectory: true))
            ready = false;explanation = "共享草稿目录无法写入，暂时可导入录屏。";diagnostics += "\n草稿目录创建失败：\(error.localizedDescription)"
        }
        captureReady = ready;captureExplanation = explanation;captureDiagnostics = diagnostics
        lastPresentedDate = UserDefaults.standard.object(forKey: "lastPresentedResultDate") as? Date ?? .distantPast
        do {capturePreferences = try CapturePreferencesStore(root: store.root).load()}
        catch {message = "自动停止设置读取失败，请在设置中重新保存后再录屏。"}
        do {toolPreferences = try ToolPreferencesStore(root:store.root).load()}
        catch {message = "设置读取失败，请重新保存设置。"}
        refresh()
    }
    func refresh() {
        do {let loaded = try store.all();if loaded != sessions {sessions = loaded}}
        catch {message = error.localizedDescription}
    }
    var hasActiveCapture: Bool {sessions.contains {$0.state == .recording || $0.state == .paused}}
    func refreshAndProcess() {
        guard !busy,!savingPhotos else {return}
        refresh()
        guard let next = ResultInbox.next(in: sessions,after: lastPresentedDate),destination?.id != SessionDestination.result(next).id else {return}
        destination = .result(next)
        if next.outputs.isEmpty {export(next.id,crop: next.crop,outer: next.outerCrop)}
    }
    func openSession(_ session: SessionManifest) {
        if session.outputs.isEmpty {
            if session.state == .ready {markResultPresented(session)}
            destination = .editor(session)
        } else {destination = .result(session)}
    }
    func markResultPresented(_ session: SessionManifest) {
        guard session.createdAt > lastPresentedDate else {return}
        lastPresentedDate = session.createdAt
        UserDefaults.standard.set(lastPresentedDate,forKey: "lastPresentedResultDate")
    }
    @discardableResult func saveCapturePreferences(enabled: Bool,seconds: String) -> Bool {
        let text = seconds.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",",with: ".")
        let requested: Double? = enabled ? Double(text) : capturePreferences.idleSeconds
        guard let interval = requested else {message = "请输入大于 0 的秒数，可使用小数。";return false}
        do {
            let value = try CapturePreferences(idleStopEnabled: enabled,idleSeconds: interval).validated()
            try CapturePreferencesStore(root: store.root).save(value);capturePreferences = value;return true
        } catch {message = error.localizedDescription;return false}
    }
    func cancel() { operation?.cancel() }
    func copyImages(_ session: SessionManifest,completion: @escaping(Int)->Void) {
        guard !busy,!savingPhotos else {return}
        let urls = outputURLs(session)
        guard !urls.isEmpty,urls.count == session.outputs.count else {
            message = "长截图文件不完整，请重新生成后再复制。";return
        }
        busy = true;progress = 0;phase = "复制到剪贴板"
        operation = Task {
            // Transfer compressed PNG bytes directly. Decoding an entire long
            // screenshot to UIImage would require much more working memory.
            let worker = Task.detached(priority: .userInitiated) {
                try urls.map {url -> Data in
                    try Task.checkCancellation()
                    let data = try Data(contentsOf: url,options: .mappedIfSafe)
                    guard !data.isEmpty else {throw ScrollShotError.io("长截图文件为空，请重新生成后再复制。")}
                    return data
                }
            }
            defer {busy = false}
            do {
                let images = try await withTaskCancellationHandler(operation: {try await worker.value},onCancel: {worker.cancel()})
                try Task.checkCancellation()
                guard UIApplication.shared.applicationState == .active else {throw ScrollShotError.unavailable("请返回轻卷截图后再次复制。")}
                // Commit all pages at once: a read failure leaves the user's
                // previous clipboard intact instead of copying a partial result.
                UIPasteboard.general.setItems(images.map {[UTType.png.identifier: $0]},options: [:])
                progress = 1;completion(images.count)
            } catch {
                message = error is CancellationError ? "已取消复制，剪贴板内容未更改。":error.localizedDescription
            }
        }
    }
    @discardableResult func saveTools(_ value:ToolPreferences)->Bool {
        do {try ToolPreferencesStore(root:store.root).save(value);toolPreferences=value;return true}
        catch {message=error.localizedDescription;return false}
    }
    func delete(_ session:SessionManifest) {
        guard !busy,!savingPhotos else {message="请等待当前任务或相册保存完成后删除";return}
        do {try store.delete(session.id);refresh()} catch {message=error.localizedDescription}
    }
    func compress(_ id:UUID,completion:@escaping(Bool)->Void) {
        guard !busy,!savingPhotos else {return}
        busy=true;progress=0;phase="压缩图片，保留原图"
        let store=store
        operation=Task {
            let worker=Task.detached(priority:.userInitiated) {
                let session=try store.load(id)
                if session.renderedTiles?.isEmpty != false {
                    try ExportService.generate(id:id,store:store,crop:session.crop,outer:session.outerCrop,edits:session.pageEdits ?? [],removeScrollbar:session.scrollbarRemoval ?? false,progress:{_ in})
                }
                return try CompressionService.generate(id:id,store:store)
            }
            do {_ = try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()});busy=false;progress=1;refresh();completion(true)}
            catch {busy=false;refresh();message=error is CancellationError ? "已取消压缩，原图仍在。":error.localizedDescription;completion(false)}
        }
    }
    func importVideo(_ url: URL,removeAfter: Bool = false) {
        guard !busy,!savingPhotos else { return }
        busy = true; progress = 0; phase = "读取录屏画面"
        let store = store
        operation = Task {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
                if removeAfter { try? FileManager.default.removeItem(at: url) }
            }
            let report: @Sendable(Double)->Void = { [weak self] p in Task { @MainActor in self?.progress = p } }
            let worker = Task.detached(priority: .userInitiated) {
                try await ImportService.importVideo(url: url,store: store,progress: report)
            }
            do {
                let result = try await withTaskCancellationHandler(operation: {try await worker.value},onCancel: {worker.cancel()})
                busy = false; refresh(); destination = .result(result)
                export(result.id,crop: result.crop,outer: result.outerCrop)
            } catch {
                busy = false; refresh()
                message = error is CancellationError ? "已取消，已采集的画面保存在草稿中。" : error.localizedDescription
            }
        }
    }
    @discardableResult func export(_ id: UUID,crop: CropInsets,outer: CropInsets,edits:[PageEdit] = [],removeScrollbar:Bool? = nil)->Bool {
        guard !busy,!savingPhotos else {message="请等待当前任务和相册保存完成后再应用编辑。";return false}
        busy = true; progress = 0; phase = "复核重叠与拼接"
        let store = store
        let clean=removeScrollbar ?? toolPreferences.smartScrollbar
        operation = Task {
            let report: @Sendable(Double)->Void = { [weak self] p in Task { @MainActor in self?.progress = p } }
            let worker = Task.detached(priority: .userInitiated) {
                try ExportService.generate(id:id,store:store,crop:crop,outer:outer,edits:edits,removeScrollbar:clean,progress:report)
            }
            do {
                try await withTaskCancellationHandler(operation: {try await worker.value},onCancel: {worker.cancel()})
                busy = false; progress = 1; refresh()
            } catch {
                busy = false; refresh()
                message = error is CancellationError ? "已取消导出，原始草稿和已有结果仍在。" : error.localizedDescription
            }
        }
        return true
    }
    func recover(_ session: SessionManifest) {
        do { try store.recover(session,currentlyCapturing: UIScreen.main.isCaptured); refresh() } catch { message = error.localizedDescription }
    }
    func outputURLs(_ session: SessionManifest,compressed:Bool = false) -> [URL] {
        let root = store.directory(for: session.id).standardizedFileURL
        return (compressed ? (session.compressedOutputs ?? []):session.outputs).compactMap { name in
            let url = root.appendingPathComponent(name).standardizedFileURL
            guard url.path.hasPrefix(root.path+"/"),FileManager.default.fileExists(atPath: url.path) else { return nil }
            return url
        }
    }
}
