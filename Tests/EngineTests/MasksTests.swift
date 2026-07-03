import XCTest
@testable import dkey

final class MasksTests: XCTestCase {
    func testKeyCodes() {
        XCTAssertEqual(KeyCode.a, 0)
        XCTAssertEqual(KeyCode.s, 1)
        XCTAssertEqual(KeyCode.w, 13)
        XCTAssertEqual(KeyCode.z, 6)
    }
    func testCharacterMap() {
        XCTAssertEqual(KeyCode.keyCode(for: "a")?.code, KeyCode.a)
        XCTAssertEqual(KeyCode.keyCode(for: "A")?.caps, true)
        XCTAssertEqual(KeyCode.keyCode(for: "s")?.code, KeyCode.s)
    }
    func testMaskAccessors() {
        let cell: UInt32 = UInt32(KeyCode.a) | EngineMask.mark1 | EngineMask.caps
        XCTAssertEqual(cell.cellKeyCode, KeyCode.a)
        XCTAssertTrue(cell.cellHasMark)
        XCTAssertTrue(cell.cellHasCaps)
    }
}
