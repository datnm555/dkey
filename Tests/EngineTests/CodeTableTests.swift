import XCTest
@testable import dkey

final class CodeTableTests: XCTestCase {
    func testBaseVowelRow() {
        // KEY_A row: index 5 = á (normal sắc), index 1 = â, index 3 = ă
        let row = codeTableUnicode[UInt32(KeyCode.a)]!
        XCTAssertEqual(row[5], 0x00E1) // á
        XCTAssertEqual(row[1], 0x00E2) // â
        XCTAssertEqual(row[3], 0x0103) // ă
    }
    func testCircumflexRow() {
        // KEY_A|TONE row index 1 = ấ
        let row = codeTableUnicode[UInt32(KeyCode.a) | EngineMask.tone]!
        XCTAssertEqual(row[1], 0x1EA5) // ấ
    }
    func testDRow() {
        XCTAssertEqual(codeTableUnicode[UInt32(KeyCode.d)]![1], 0x0111) // đ
    }
    func testKeyCodeToCharacter() {
        XCTAssertEqual(keyCodeToCharacter(UInt32(KeyCode.a)), UInt16(Character("a").asciiValue!))
        XCTAssertEqual(keyCodeToCharacter(UInt32(KeyCode.s)), UInt16(Character("s").asciiValue!))
    }
    func testIRowTildeCorrection() {
        let row = codeTableUnicode[UInt32(KeyCode.i)]!
        XCTAssertEqual(row[6], 0x0128) // Ĩ — brief-mandated 4-digit correction
        XCTAssertEqual(row[7], 0x0129) // ĩ
    }
}
