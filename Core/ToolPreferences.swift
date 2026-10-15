import Foundation
public struct ToolPreferences: Codable,Sendable,Equatable {
    public var smartScrollbar = true
    public var haptics = true
    public var compressionPromptMB = 20.0
    public init() {}
    public func validated() throws -> Self {
        guard compressionPromptMB.isFinite,compressionPromptMB>0 else {throw ScrollShotError.invalidInput("压缩提醒大小必须是大于 0 的 MB 数")};return self
    }
}
public struct ToolPreferencesStore {
    public let root: URL
    public init(root: URL) {self.root=root}
    public func load() throws -> ToolPreferences {
        let path=root.appendingPathComponent("tool-settings.json")
        guard FileManager.default.fileExists(atPath:path.path) else {return ToolPreferences()}
        return try JSONDecoder().decode(ToolPreferences.self,from:Data(contentsOf:path)).validated()
    }
    public func save(_ value: ToolPreferences) throws {
        let value=try value.validated();try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        try JSONEncoder().encode(value).write(to:root.appendingPathComponent("tool-settings.json"),options:.atomic)
    }
}
public final class CaptureFeedbackGate: @unchecked Sendable {
    private let lock=NSLock(),enabled:Bool,feedback:@Sendable()->Void
    private var started=false,stopped=false
    public init(enabled: Bool,feedback: @escaping @Sendable()->Void) {self.enabled=enabled;self.feedback=feedback}
    public func start() {let fire=lock.withLock {if started {return false};started=true;return enabled};if fire {feedback()}}
    public func stop() {let fire=lock.withLock {guard started,!stopped else {return false};stopped=true;return enabled};if fire {feedback()}}
}
