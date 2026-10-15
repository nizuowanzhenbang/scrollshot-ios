import Foundation
public struct CapturePreferences: Codable, Sendable, Equatable {
    public var idleStopEnabled: Bool
    public var idleSeconds: Double
    public init(idleStopEnabled: Bool = true,idleSeconds: Double = 3) {self.idleStopEnabled = idleStopEnabled;self.idleSeconds = idleSeconds}
    public func validated() throws -> Self {self}
}
public struct CapturePreferencesStore: Sendable {
    public let root: URL
    public init(root: URL) {self.root = root}
    public func load() throws -> CapturePreferences {CapturePreferences()}
    public func save(_ value: CapturePreferences) throws {}
}
