import Foundation
public enum ExportService {
    public static func generate(id: UUID,store: SessionStore,crop: CropInsets,outer: CropInsets,progress: (Double)->Void) throws {
                var session = try store.load(id)
                guard session.state != .recording && session.state != .paused else { throw ScrollShotError.unavailable("请先停止系统录屏；异常中断的草稿可稍后恢复。") }
                let directory = store.directory(for: id)
                let refined = try Refinement.records(session.frames,directory: directory,crop: crop,progress: {progress($0*0.2)})
                let segments = try StitchPlanner.build(records: refined,crop: crop)
                guard !segments.isEmpty else { throw ScrollShotError.invalidInput("草稿没有有效图像") }
                var pages: [StitchSegment] = []
                for segment in segments {
                    let trimmed = try StitchPlanner.trim(segment,top: outer.top,bottom: outer.bottom)
                    pages += try StitchPlanner.split(trimmed)
                }
                let exportName = "export-"+UUID().uuidString
                let exportDirectory = directory.appendingPathComponent(exportName,isDirectory: true)
                var outputs: [String] = []
                for (i,page) in pages.enumerated() {
                    let url = try StripRenderer.export(segment: page,sessionDirectory: directory,outputDirectory: exportDirectory,progress: {progress(0.2+0.8*(Double(i)+$0)/Double(pages.count))})
                    outputs.append(exportName+"/"+url.lastPathComponent)
                }
                if segments.count > 1 && !session.warnings.contains("检测到多个连续片段，结果已分别保存。") { session.warnings.append("检测到多个连续片段，结果已分别保存。") }
                session.frames = refined; session.crop = crop; session.outerCrop = outer; session.outputs = outputs
                try store.save(session)
    }
}
