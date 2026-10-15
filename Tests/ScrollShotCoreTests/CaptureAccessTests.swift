import XCTest
@testable import ScrollShotCore

final class CaptureAccessTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/shared")
    func testReadsOnlyGroupMetadataFromCMSWrappedProfile() throws {
        let data = try profile(["group.synthetic.b","group.synthetic.a","group.synthetic.a"])
        XCTAssertEqual(CaptureAccess.profileGroups(data),["group.synthetic.a","group.synthetic.b"])
        XCTAssertNil(CaptureAccess.profileGroups(Data([0,1,2])))
        XCTAssertNil(CaptureAccess.profileGroups(Data("<?xml broken</plist>".utf8)))
        XCTAssertEqual(CaptureAccess.profileGroups(try profile([])),[])
    }
    func testResignedCommonGroupReplacesUnavailableBuildGroup() throws {
        let result = try XCTUnwrap(CaptureAccess.select(configured: "group.build.original",hostGroups: ["group.synthetic.b","group.synthetic.a"],extensionGroups: ["group.synthetic.a","group.synthetic.b"],container: {$0 == "group.synthetic.b" ? self.root : nil}))
        XCTAssertEqual(result.group,"group.synthetic.b")
        XCTAssertEqual(result.drafts.path,"/shared/ScrollShot/Drafts")
    }
    func testMainAndExtensionChooseSameGroupDespiteProfileOrder() throws {
        let a = ["group.synthetic.b","group.synthetic.a"],b = Array(a.reversed())
        let main = try XCTUnwrap(CaptureAccess.select(configured: nil,hostGroups: a,extensionGroups: b,container: {_ in self.root}))
        let ext = try XCTUnwrap(CaptureAccess.select(configured: nil,hostGroups: b,extensionGroups: a,container: {_ in self.root}))
        XCTAssertEqual(main.group,"group.synthetic.a");XCTAssertEqual(main.group,ext.group)
    }
    func testAsymmetricProcessAccessNeverSilentlySplitsDrafts() throws {
        let groups = ["group.synthetic.a","group.synthetic.b"]
        let main = try XCTUnwrap(CaptureAccess.select(configured: nil,hostGroups: groups,extensionGroups: groups,container: {_ in self.root}))
        let ext = CaptureAccess.select(configured: nil,hostGroups: groups,extensionGroups: groups,container: {$0 == "group.synthetic.b" ? self.root : nil})
        XCTAssertEqual(main.group,"group.synthetic.a")
        XCTAssertNil(ext,"An extension may not silently switch to B while the host uses A")
    }
    func testNeverChoosesGroupUnavailableToEitherProcessOrTheOS() {
        XCTAssertNil(CaptureAccess.select(configured: "group.build.original",hostGroups: ["group.main.only"],extensionGroups: ["group.ext.only"],container: {_ in self.root}))
        XCTAssertNil(CaptureAccess.select(configured: nil,hostGroups: ["group.common"],extensionGroups: ["group.common"],container: {_ in nil}))
        XCTAssertNil(CaptureAccess.select(configured: nil,hostGroups: ["group.common"],extensionGroups: nil,container: {_ in self.root}))
    }
    func testOriginalConfigurationPreservesExistingDraftDirectory() throws {
        let result = try XCTUnwrap(CaptureAccess.select(configured: "group.build.original",hostGroups: nil,extensionGroups: nil,container: {_ in self.root}))
        XCTAssertEqual(result.drafts.path,"/shared/Drafts")
    }
    func testInspectsActualEmbeddedExtensionFromEitherProcess() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at: directory)}
        let host = directory.appendingPathComponent("Host.app"),ext = host.appendingPathComponent("PlugIns/Renamed.appex")
        try FileManager.default.createDirectory(at: ext,withIntermediateDirectories: true)
        try plist(["CFBundleIdentifier":"org.synthetic.renamed","AppGroupIdentifier":"group.build.original"]).write(to: host.appendingPathComponent("Info.plist"))
        try plist(["CFBundleIdentifier":"org.synthetic.renamed.Upload","NSExtension":["NSExtensionPointIdentifier":"com.apple.broadcast-services-upload"]]).write(to: ext.appendingPathComponent("Info.plist"))
        try profile(["group.synthetic.shared"]).write(to: host.appendingPathComponent("embedded.mobileprovision"))
        try profile(["group.synthetic.shared"]).write(to: ext.appendingPathComponent("embedded.mobileprovision"))
        for bundle in [host,ext] {
            let access = CaptureAccess.inspect(bundleURL: bundle,container: {$0 == "group.synthetic.shared" ? self.root : nil})
            XCTAssertEqual(access.extensionIdentifier,"org.synthetic.renamed.Upload")
            XCTAssertEqual(access.container?.group,"group.synthetic.shared")
        }
    }
    func testMissingExtensionIsReportedWithoutPretendingCaptureIsReady() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Host.app")
        try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
        defer {try? FileManager.default.removeItem(at: directory.deletingLastPathComponent())}
        try plist(["CFBundleIdentifier":"org.synthetic.host"]).write(to: directory.appendingPathComponent("Info.plist"))
        let access = CaptureAccess.inspect(bundleURL: directory,container: {_ in self.root})
        XCTAssertNil(access.container);XCTAssertTrue(access.diagnostics.contains("缺少录屏扩展"))
    }
    private func plist(_ dictionary: [String:Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: dictionary,format: .xml,options: 0)
    }
    private func profile(_ groups: [String]) throws -> Data {
        var wrapped = Data([0x30,0x82,0,1])
        wrapped.append(try plist(["Entitlements":["com.apple.security.application-groups":groups]]))
        wrapped.append(Data([0,0xff]));return wrapped
    }
}
