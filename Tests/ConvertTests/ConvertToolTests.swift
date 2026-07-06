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

    func testRemoveMarkPreservesCaseInKeep() {
        XCTAssertEqual(ConvertTool.convert("VIỆT", from: .unicode, to: .unicode, removeMark: true), "VIET")
        XCTAssertEqual(ConvertTool.convert("Tiếng", from: .unicode, to: .unicode, removeMark: true), "Tieng")
    }

    // Fix A: keep mode must preserve case on in-table vowels (not just passthrough chars).
    // Previously, uppercase Vietnamese vowels (e.g. Ế in TIẾNG) were force-lowercased.
    func testKeepModePreservesCase() {
        XCTAssertEqual(
            ConvertTool.convert("TIẾNG Việt", from: .unicode, to: .unicode, caseMode: .keep),
            "TIẾNG Việt"
        )
    }

    // Sentence mode: capitalize only the first letter after a sentence break (. ? !) + space.
    func testCaseSentence() {
        XCTAssertEqual(
            ConvertTool.convert("tiếng việt. xin chào", from: .unicode, to: .unicode, caseMode: .sentence),
            "Tiếng việt. Xin chào"
        )
    }

    // Title mode: capitalize the first letter of every word (space-separated).
    func testCaseTitle() {
        XCTAssertEqual(
            ConvertTool.convert("tiếng việt. xin chào", from: .unicode, to: .unicode, caseMode: .title),
            "Tiếng Việt. Xin Chào"
        )
    }
}
