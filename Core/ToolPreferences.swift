import Foundation
public struct ToolPreferences: Codable,Sendable,Equatable {
    public var smartScrollbar = true
    public var haptics = true
    public var compressionPromptMB = 20.0
    public init() {}
}
public struct ToolPreferencesStore {
    public let root: URL
    public init(root: URL) {self.root=root}
    public func load() throws -> ToolPreferences {ToolPreferences()}
    public func save(_ value: ToolPreferences) throws {}
}
public final class CaptureFeedbackGate: @unchecked Sendable {
    public init(enabled: Bool,feedback: @escaping @Sendable()->Void) {}
    public func start() {}
    public func stop() {}
}
