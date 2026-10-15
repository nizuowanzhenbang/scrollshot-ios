import Foundation
public final class SessionStore: @unchecked Sendable {
    public let root: URL
    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
    }
    public func directory(for id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    public func create() throws -> SessionManifest {
        let session = SessionManifest()
        try FileManager.default.createDirectory(at: directory(for: session.id),withIntermediateDirectories: false)
        try save(session); return session
    }
    public func save(_ session: SessionManifest) throws {
        var copy = session; copy.updatedAt = Date()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(copy).write(to: directory(for: session.id).appendingPathComponent("session.json"),options: .atomic)
    }
    public func load(_ id: UUID) throws -> SessionManifest {
        let data = try Data(contentsOf: directory(for: id).appendingPathComponent("session.json"))
        return try JSONDecoder().decode(SessionManifest.self,from: data)
    }
    public func all() throws -> [SessionManifest] {
        try FileManager.default.contentsOfDirectory(at: root,includingPropertiesForKeys: nil)
            .compactMap { url -> SessionManifest? in
                guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
                return try? load(id)
            }.sorted {$0.createdAt > $1.createdAt}
    }
    public func writeFrame(_ data: Data, fileName: String, session: UUID) throws {
        let url = try Self.fileURL(fileName,in: directory(for: session))
        guard !FileManager.default.fileExists(atPath: url.path) else { throw ScrollShotError.io("图像文件已存在") }
        try data.write(to: url,options: .atomic)
    }
    public static func fileURL(_ name: String,in directory: URL) throws -> URL {
        guard !name.isEmpty, !name.contains("/"), !name.contains("\\"), !name.hasPrefix(".") else {
            throw ScrollShotError.invalidInput("图像文件名无效")
        }
        return directory.appendingPathComponent(name)
    }
}
