import Foundation
public struct CapturePreferences: Codable, Sendable, Equatable {
    public var idleStopEnabled: Bool
    public var idleSeconds: Double
    // Motion is sampled at 5 Hz. Leave room for a new moving observation
    // before an extremely short user setting can expire between samples.
    public var effectiveIdleSeconds: Double {max(0.3,idleSeconds)}
    public init(idleStopEnabled: Bool = true,idleSeconds: Double = 3) {self.idleStopEnabled = idleStopEnabled;self.idleSeconds = idleSeconds}
    public func validated() throws -> Self {
        guard idleSeconds.isFinite,idleSeconds > 0 else {throw ScrollShotError.invalidInput("自动停止秒数必须是大于 0 的有效数字。")}
        return self
    }
}
public struct CapturePreferencesStore: Sendable {
    public let root: URL
    public init(root: URL) {self.root = root}
    private var file: URL {root.appendingPathComponent("capture-settings.json")}
    public func load() throws -> CapturePreferences {
        guard FileManager.default.fileExists(atPath: file.path) else {return CapturePreferences()}
        return try JSONDecoder().decode(CapturePreferences.self,from: Data(contentsOf: file)).validated()
    }
    public func save(_ value: CapturePreferences) throws {
        let value = try value.validated()
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: file,options: .atomic)
    }
}
