import XCTest
@testable import dkey

final class ConvertToolTests: XCTestCase {
    private func roundTrip(_ s: String, via t: CodeTable) -> String {
        let enc = ConvertTool.convert(s, from: .unicode, to: t)
        return ConvertTool.convert(enc, from: t, to: .unicode)
    }

    func testRoundTripAllTables() {
        let s = "Tiếng Việt thân thương"
        for t: CodeTable in [.tcvn3, .vniWindows, .unicodeCompound, .cp1258] {
            XCTAssertEqual(roundTrip(s, via: t), s, "round-trip via \(t) failed")
        }
    }

    func testNonVietnamesePassthrough() {
        XCTAssertEqual(ConvertTool.convert("abc 123 @#", from: .unicode, to: .tcvn3), "abc 123 @#")
    }

    func testCaseUpper() {
        XCTAssertEqual(ConvertTool.convert("tiếng việt", from: .unicode, to: .unicode, caseMode: .upper), "TIẾNG VIỆT")
    }

    func testCaseLower() {
        XCTAssertEqual(ConvertTool.convert("TIẾNG VIỆT", from: .unicode, to: .unicode, caseMode: .lower), "tiếng việt")
    }

    func testRemoveMark() {
        XCTAssertEqual(ConvertTool.convert("tiếng Việt", from: .unicode, to: .unicode, removeMark: true), "tieng Viet")
    }
}
