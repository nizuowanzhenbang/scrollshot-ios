import Foundation
import SwiftUI
import UIKit
import ScrollShotCore

@MainActor final class AppModel: ObservableObject {
    @Published var sessions: [SessionManifest] = []
    @Published var selected: SessionManifest?
    @Published var busy = false
    @Published var progress = 0.0
    @Published var phase = ""
    @Published var message: String?
    let store: SessionStore
    let captureReady: Bool
    let captureExplanation: String
    private var operation: Task<Void,Never>?
    private var attempted: Set<UUID> = []
    init() {
        let documents = FileManager.default.urls(for: .documentDirectory,in: .userDomainMask)[0]
        var root = documents.appendingPathComponent("Drafts",isDirectory: true)
        #if IMPORT_ONLY
        captureReady = false
        captureExplanation = "从相册或文件导入系统录屏，在本机生成长图。"
        #else
        if let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
           let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
            root = container.appendingPathComponent("Drafts",isDirectory: true)
            captureReady = true; captureExplanation = "开始后切到目标 App 匀速向下滚动，停止录屏后返回。"
        } else {
            captureReady = false; captureExplanation = "共享权限自检未通过。可先导入录屏，或安装不带共享权限的导入版。"
        }
        #endif
        do { store = try SessionStore(root: root) }
        catch {
            // A writable app-local fallback keeps imported drafts usable.
            store = try! SessionStore(root: documents.appendingPathComponent("LocalDrafts",isDirectory: true))
        }
        refresh()
    }
    func refresh() { do { sessions = try store.all() } catch { message = error.localizedDescription } }
    func refreshAndProcess() {
        refresh()
        guard !busy,let s = sessions.first(where: {$0.state == .ready && !$0.frames.isEmpty && $0.outputs.isEmpty && !attempted.contains($0.id)}) else { return }
        attempted.insert(s.id); selected = s; export(s.id,crop: s.crop,outer: s.outerCrop)
    }
    func cancel() { operation?.cancel() }
    func importVideo(_ url: URL,removeAfter: Bool = false) {
        guard !busy else { return }
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
                busy = false; refresh(); selected = result; attempted.insert(result.id)
                export(result.id,crop: result.crop,outer: result.outerCrop)
            } catch {
                busy = false; refresh()
                message = error is CancellationError ? "已取消，已采集的画面保存在草稿中。" : error.localizedDescription
            }
        }
    }
    func export(_ id: UUID,crop: CropInsets,outer: CropInsets) {
        guard !busy else { return }
        busy = true; progress = 0; phase = "复核重叠与拼接"
        let store = store
        operation = Task {
            let report: @Sendable(Double)->Void = { [weak self] p in Task { @MainActor in self?.progress = p } }
            let worker = Task.detached(priority: .userInitiated) {
                try ExportService.generate(id: id,store: store,crop: crop,outer: outer,progress: report)
            }
            do {
                try await withTaskCancellationHandler(operation: {try await worker.value},onCancel: {worker.cancel()})
                busy = false; progress = 1; refresh()
            } catch {
                busy = false; refresh()
                message = error is CancellationError ? "已取消导出，原始草稿和已有结果仍在。" : error.localizedDescription
            }
        }
    }
    func recover(_ session: SessionManifest) {
        do { try store.recover(session,currentlyCapturing: UIScreen.main.isCaptured); refresh() } catch { message = error.localizedDescription }
    }
    func outputURLs(_ session: SessionManifest) -> [URL] {
        let root = store.directory(for: session.id).standardizedFileURL
        return session.outputs.compactMap { name in
            let url = root.appendingPathComponent(name).standardizedFileURL
            guard url.path.hasPrefix(root.path+"/"),FileManager.default.fileExists(atPath: url.path) else { return nil }
            return url
        }
    }
}
