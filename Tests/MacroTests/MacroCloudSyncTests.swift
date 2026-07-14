import XCTest
@testable import dkey

/// Codec & merge cho đồng bộ Gõ tắt qua iCloud — logic thuần, không I/O/iCloud.
final class MacroCloudSyncTests: XCTestCase {
    func testCodecRoundTrip() {
        let macros = [Macro(key: "btw", content: "by the way"),
                      Macro(key: "omw", content: "on my way")]
        let data = MacroSyncCodec.encode(macros)
        XCTAssertEqual(MacroSyncCodec.decode(data), macros)
    }

    func testDecodeGarbageIsEmpty() {
        XCTAssertEqual(MacroSyncCodec.decode(Data("không phải json".utf8)), [])
    }

    func testMergeAddsRemoteOnlyKeys() {
        let local = [Macro(key: "a", content: "1")]
        let remote = [Macro(key: "b", content: "2")]
        let merged = MacroMerge.merged(local: local, remote: remote)
        XCTAssertEqual(merged, [Macro(key: "a", content: "1"), Macro(key: "b", content: "2")])
    }

    func testMergeRemoteOverridesConflict() {
        let local = [Macro(key: "a", content: "cũ")]
        let remote = [Macro(key: "a", content: "mới")]
        XCTAssertEqual(MacroMerge.merged(local: local, remote: remote),
                       [Macro(key: "a", content: "mới")])
    }

    func testMergeKeepsLocalOnlyKeys() {
        let local = [Macro(key: "a", content: "1"), Macro(key: "b", content: "2")]
        let remote = [Macro(key: "a", content: "1")]
        XCTAssertEqual(MacroMerge.merged(local: local, remote: remote), local)
    }

    func testMergeEmptyRemoteKeepsLocal() {
        let local = [Macro(key: "a", content: "1")]
        XCTAssertEqual(MacroMerge.merged(local: local, remote: []), local)
    }
}
