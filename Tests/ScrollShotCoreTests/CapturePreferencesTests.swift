import XCTest
@testable import ScrollShotCore
final class CapturePreferencesTests: XCTestCase {
    func testDefaultsAndSharedFileRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at: root)}
        let store = CapturePreferencesStore(root: root)
        XCTAssertEqual(try store.load(),CapturePreferences())
        let changed = CapturePreferences(idleStopEnabled: false,idleSeconds: 7.25)
        try store.save(changed)
        XCTAssertEqual(try CapturePreferencesStore(root: root).load(),changed)
    }
    func testInvalidSecondsNeverReplaceTheSavedValue() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at: root)}
        let store = CapturePreferencesStore(root: root),valid = CapturePreferences(idleSeconds: 0.125)
        try store.save(valid)
        for seconds in [0,-1,Double.infinity,Double.nan] {
            XCTAssertThrowsError(try store.save(CapturePreferences(idleSeconds: seconds)))
        }
        XCTAssertEqual(try store.load(),valid)
    }
    func testOlderManifestWithoutFinishReasonStillLoads() throws {
        let original = SessionManifest();var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String:Any])
        json.removeValue(forKey: "finishReason")
        let recovered = try JSONDecoder().decode(SessionManifest.self,from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(recovered.id,original.id);XCTAssertNil(recovered.finishReason)
    }
}
