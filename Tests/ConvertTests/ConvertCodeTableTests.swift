import XCTest
@testable import dkey

final class ConvertCodeTableTests: XCTestCase {
    func testAllFiveTablesPresent() {
        XCTAssertEqual(CodeTable.allCases.count, 5)
        for t in CodeTable.allCases {
            XCTAssertFalse(CodeTable.table(t).isEmpty, "\(t) table empty")
        }
    }

    func testUnicodeTableIsExistingCodeTable() {
        // Table [0] reuses codeTableUnicode: 'a' row starts with Â/â precomposed.
        XCTAssertEqual(CodeTable.table(.unicode)[UInt32(KeyCode.a)]?.first, 0x00C2)
    }

    func testTCVN3KnownBytes() {
        // TCVN3 'a' row first entries (Vietnamese.cpp:431): Â=0xA2, â=0xA9.
        let row = CodeTable.table(.tcvn3)[UInt32(KeyCode.a)]
        XCTAssertEqual(row?[0], 0xA2)
        XCTAssertEqual(row?[1], 0xA9)
    }

    func testCompoundMarkCount() {
        XCTAssertEqual(unicodeCompoundMark.count, 5)
        XCTAssertEqual(unicodeCompoundMark[0], 0x0301) // sắc
    }
}
