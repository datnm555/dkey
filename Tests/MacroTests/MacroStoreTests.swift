import XCTest
@testable import dkey

final class MacroStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func testLoadEmptyWhenMissing() {
        XCTAssertEqual(MacroStore(directory: tempDir()).load(), [])
    }

    func testRoundTrip() {
        let store = MacroStore(directory: tempDir())
        let macros = [Macro(key: "vn", content: "Việt Nam"), Macro(key: "hn", content: "Hà Nội")]
        store.save(macros)
        XCTAssertEqual(store.load(), macros)
    }

    func testCorruptFileLoadsEmpty() {
        let dir = tempDir()
        try? "not json".data(using: .utf8)!.write(to: dir.appendingPathComponent("macros.json"))
        XCTAssertEqual(MacroStore(directory: dir).load(), [])
    }

    func testExportImportJSON() throws {
        let store = MacroStore(directory: tempDir())
        let macros = [Macro(key: "vn", content: "Việt Nam")]
        let file = tempDir().appendingPathComponent("export.json")
        try store.export(macros, to: file)
        XCTAssertEqual(store.importMacros(from: file), macros)
    }

    func testImportTSV() throws {
        let file = tempDir().appendingPathComponent("in.txt")
        try "vn\tViệt Nam\nhn\tHà Nội\n".data(using: .utf8)!.write(to: file)
        XCTAssertEqual(MacroStore(directory: tempDir()).importMacros(from: file),
                       [Macro(key: "vn", content: "Việt Nam"), Macro(key: "hn", content: "Hà Nội")])
    }
}
