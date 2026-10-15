import Foundation

public struct SharedCaptureContainer: Sendable {
    public let group: String
    public let drafts: URL
}
public struct CaptureAccess: Sendable {
    public let extensionIdentifier: String?
    public let container: SharedCaptureContainer?
    public let diagnostics: String
    public static func profileGroups(_ data: Data) -> [String]? { nil }
    public static func select(configured: String?,hostGroups: [String]?,extensionGroups: [String]?,container: (String)->URL?) -> SharedCaptureContainer? {
        guard let configured,let url = container(configured) else { return nil }
        return SharedCaptureContainer(group: configured,drafts: url.appendingPathComponent("Drafts",isDirectory: true))
    }
    public static func inspect(bundleURL: URL,container: (String)->URL?) -> CaptureAccess {
        CaptureAccess(extensionIdentifier: nil,container: nil,diagnostics: "尚未检查")
    }
}
