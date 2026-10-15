import Foundation

public struct SharedCaptureContainer: Sendable {
    public let group: String
    public let drafts: URL
}
public struct CaptureAccess: Sendable {
    public let extensionIdentifier: String?
    public let container: SharedCaptureContainer?
    public let diagnostics: String
    /// Extract metadata only. A profile's text is never treated as authority:
    /// every selected group must also pass the running process's OS access check.
    public static func profileGroups(_ data: Data) -> [String]? {
        guard data.count <= 2*1024*1024,
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8),in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound],format: nil) as? [String:Any],
              let entitlements = plist["Entitlements"] as? [String:Any] else { return nil }
        guard let value = entitlements["com.apple.security.application-groups"] else { return [] }
        guard let groups = value as? [String],groups.count <= 100 else { return nil }
        return Array(Set(groups.filter(validGroup))).sorted()
    }
    public static func select(configured: String?,hostGroups: [String]?,extensionGroups: [String]?,container: (String)->URL?) -> SharedCaptureContainer? {
        var candidates: [String] = []
        if let configured,validGroup(configured),hostGroups?.contains(configured) != false,extensionGroups?.contains(configured) != false {
            candidates.append(configured)
        }
        if let hostGroups,let extensionGroups {
            candidates += Set(hostGroups).intersection(extensionGroups).filter(validGroup).sorted().filter {$0 != configured}
        }
        for group in candidates {
            guard let root = container(group) else { continue }
            // Keep existing drafts for the original group; namespace re-signed
            // groups because a signing profile may authorize other apps too.
            let base = group == configured ? root : root.appendingPathComponent("ScrollShot",isDirectory: true)
            return SharedCaptureContainer(group: group,drafts: base.appendingPathComponent("Drafts",isDirectory: true))
        }
        return nil
    }
    public static func inspect(bundleURL: URL,container: (String)->URL?) -> CaptureAccess {
        let host = bundleURL.pathExtension == "appex" ? bundleURL.deletingLastPathComponent().deletingLastPathComponent() : bundleURL
        let hostInfo = info(host),hostID = hostInfo["CFBundleIdentifier"] as? String
        let plugins = (try? FileManager.default.contentsOfDirectory(at: host.appendingPathComponent("PlugIns"),includingPropertiesForKeys: nil)) ?? []
        let extensions = plugins.filter {
            guard $0.pathExtension == "appex",let config = info($0)["NSExtension"] as? [String:Any] else { return false }
            return config["NSExtensionPointIdentifier"] as? String == "com.apple.broadcast-services-upload"
        }
        guard extensions.count == 1,let ext = extensions.first,let extID = info(ext)["CFBundleIdentifier"] as? String else {
            return CaptureAccess(extensionIdentifier: nil,container: nil,diagnostics: extensions.isEmpty ? "安装包缺少录屏扩展。请重新签名并保留插件。" : "安装包中有多个录屏扩展，请检查签名配置。")
        }
        guard let hostID,extID.hasPrefix(hostID+".") else {
            return CaptureAccess(extensionIdentifier: extID,container: nil,diagnostics: "主程序与录屏扩展的包标识不匹配，请同步修正后重新签名。")
        }
        let configured = hostInfo["AppGroupIdentifier"] as? String
        let mainGroups = groups(host),extGroups = groups(ext)
        let shared = select(configured: configured,hostGroups: mainGroups,extensionGroups: extGroups,container: container)
        let status = shared == nil ? "没有找到双方共同授权且当前进程可访问的共享组。请检查主程序及扩展的签名权限。" : "共享容器可访问。"
        let diagnostics = "主程序：\(hostID)\n录屏扩展文件：存在\n扩展标识：\(extID)\n共享容器：\(shared == nil ? "不可用" : "可访问")\n\(status)\n扩展是否被系统录屏列表接受，仍需在手机上确认。"
        return CaptureAccess(extensionIdentifier: extID,container: shared,diagnostics: diagnostics)
    }
    private static func validGroup(_ group: String) -> Bool {
        group.hasPrefix("group.") && group.utf8.count > 6 && group.utf8.count <= 256 && group.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 46 || $0 == 45 }
    }
    private static func info(_ url: URL) -> [String:Any] {
        guard let data = try? Data(contentsOf: url.appendingPathComponent("Info.plist")),
              let value = try? PropertyListSerialization.propertyList(from: data,format: nil) as? [String:Any] else { return [:] }
        return value
    }
    private static func groups(_ url: URL) -> [String]? {
        guard let data = try? Data(contentsOf: url.appendingPathComponent("embedded.mobileprovision")) else { return nil }
        return profileGroups(data)
    }
}
