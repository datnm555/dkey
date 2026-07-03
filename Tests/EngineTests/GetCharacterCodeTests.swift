import XCTest
@testable import dkey

final class GetCharacterCodeTests: XCTestCase {
    private func scalar(_ data: UInt32) -> UInt16 {
        UInt16(TelexEngine().getCharacterCode(data) & EngineMask.char)
    }
    func testPlainVowelWithMark() {
        // a + sắc → á (0x00E1); a + huyền → à (0x00E0)
        XCTAssertEqual(scalar(UInt32(KeyCode.a) | EngineMask.mark1), 0x00E1)
        XCTAssertEqual(scalar(UInt32(KeyCode.a) | EngineMask.mark2), 0x00E0)
    }
    func testCircumflexWithMark() {
        // â + sắc → ấ (0x1EA5)
        XCTAssertEqual(scalar(UInt32(KeyCode.a) | EngineMask.tone | EngineMask.mark1), 0x1EA5)
    }
    func testHornNoMark() {
        // ơ (o + toneW, no mark) → 0x01A1
        XCTAssertEqual(scalar(UInt32(KeyCode.o) | EngineMask.toneW), 0x01A1)
    }
    func testDBar() {
        XCTAssertEqual(scalar(UInt32(KeyCode.d) | EngineMask.tone), 0x0111) // đ uses tone bit path; verify vs C++
    }
}
