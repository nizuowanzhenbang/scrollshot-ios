import Foundation
public enum ExportService {
    public static func generate(id: UUID,store: SessionStore,crop: CropInsets,outer: CropInsets,edits: [PageEdit] = [],removeScrollbar: Bool = false,progress: (Double)->Void) throws {
        var session = try store.load(id)
        guard session.state != .recording && session.state != .paused else { throw ScrollShotError.unavailable("请先停止系统录屏；异常中断的草稿可稍后恢复。") }
        let directory = store.directory(for: id)
        let refined = try Refinement.records(session.frames,directory: directory,crop: crop,progress: {progress($0*0.2)})
        let segments = try StitchPlanner.build(records: refined,crop: crop)
        guard !segments.isEmpty else { throw ScrollShotError.invalidInput("草稿没有有效图像") }
        let pages = try StitchPlanner.pages(segments: segments,outer: outer)
        guard edits.isEmpty || edits.count==pages.count else {throw ScrollShotError.invalidInput("图像片段已变化，请重新选择编辑区域")}
        let exportName = "export-"+UUID().uuidString
        let exportDirectory = directory.appendingPathComponent(exportName,isDirectory: true)
        var committed = false
        defer { if !committed { try? FileManager.default.removeItem(at: exportDirectory) } }
        let oldOutputs = session.outputs + (session.compressedOutputs ?? [])
        var outputs: [String] = []
        var tiles:[FrameRecord]=[]
        for (i,page) in pages.enumerated() {
            let result = try RasterExporter.export(segment:page,edit:edits.isEmpty ? PageEdit():edits[i],removeScrollbar:removeScrollbar,directory:directory,outputDirectory:exportDirectory,page:i,progress:{progress(0.2+0.8*(Double(i)+$0)/Double(pages.count))})
            outputs.append(exportName+"/"+result.output.lastPathComponent);tiles+=result.tiles
        }
        if segments.count > 1 && !session.warnings.contains("检测到多个连续片段，结果已分别保存。") { session.warnings.append("检测到多个连续片段，结果已分别保存。") }
        session.previewFrames = refined; session.crop = crop; session.outerCrop = outer; session.outputs = outputs
        session.pageEdits=edits;session.renderedTiles=tiles;session.scrollbarRemoval=removeScrollbar;session.compressedOutputs=nil
        try Task.checkCancellation()
        try store.save(session)
        committed = true
        // Only clean our own prior export directories after the new manifest commits.
        for name in Set(oldOutputs.compactMap({$0.split(separator: "/").first.map(String.init)})) {
            if (name.hasPrefix("export-") && UUID(uuidString:String(name.dropFirst(7))) != nil) || (name.hasPrefix("compressed-") && UUID(uuidString:String(name.dropFirst(11))) != nil) {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(name,isDirectory: true))
            }
        }
    }
}
