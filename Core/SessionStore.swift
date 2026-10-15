import Foundation
public final class SessionStore: @unchecked Sendable {
    public let root: URL
    public init(root: URL) throws { self.root = root }
    public func directory(for id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    public func create() throws -> SessionManifest { throw ScrollShotError.unavailable("Not implemented") }
    public func save(_ session: SessionManifest) throws { throw ScrollShotError.unavailable("Not implemented") }
    public func load(_ id: UUID) throws -> SessionManifest { throw ScrollShotError.unavailable("Not implemented") }
    public func all() throws -> [SessionManifest] { [] }
    public func writeFrame(_ data: Data, fileName: String, session: UUID) throws { throw ScrollShotError.unavailable("Not implemented") }
}
