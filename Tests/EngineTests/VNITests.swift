import XCTest
@testable import dkey

final class VNITests: XCTestCase {
    private func vni(_ s: String, modern: Bool = true) -> String {
        type(s, modern: modern, method: .vni)
    }

    func testTones() {
        XCTAssertEqual(vni("a1"), "á")
        XCTAssertEqual(vni("a2"), "à")
        XCTAssertEqual(vni("a3"), "ả")
        XCTAssertEqual(vni("a4"), "ã")
        XCTAssertEqual(vni("a5"), "ạ")
    }

    func testDd() {
        XCTAssertEqual(vni("d9"), "đ")
        XCTAssertEqual(vni("d9a2"), "đà")
    }

    func testRemoveTone() {
        XCTAssertEqual(vni("a1"), "á")
        XCTAssertEqual(vni("a10"), "a")   // 0 clears the tone
    }

    func testToneToggleOff() {
        // Re-typing the same tone digit removes it and emits the literal digit.
        XCTAssertEqual(vni("a11"), "a1")
    }

    func testBareDigitIsLiteral() {
        XCTAssertEqual(vni("1"), "1")
        XCTAssertEqual(vni("abc1"), "abc1")
    }

    func testBracketsAreLiteralInVNI() {
        XCTAssertEqual(vni("["), "[")
        XCTAssertEqual(vni("]"), "]")
    }

    func testCircumflex() {
        XCTAssertEqual(vni("a6"), "â")
        XCTAssertEqual(vni("e6"), "ê")
        XCTAssertEqual(vni("o6"), "ô")
        XCTAssertEqual(vni("a6s"), "âs")   // stray letter after is separate; core is a6→â, then s is literal
    }

    func testHorn() {
        XCTAssertEqual(vni("o7"), "ơ")
        XCTAssertEqual(vni("u7"), "ư")
    }

    func testBreve() {
        XCTAssertEqual(vni("a8"), "ă")
    }

    func testCircumflexThenTone() {
        XCTAssertEqual(vni("a61"), "ấ")   // â + sắc
        XCTAssertEqual(vni("o62"), "ồ")   // ô + huyền
    }

    func testWord() {
        XCTAssertEqual(vni("vie6t5"), "việt")   // v-i-ê-t + nặng
        XCTAssertEqual(vni("d9o6ng2"), "đồng")  // đ(d9)-ô-ng + huyền; VNI uses d9 for đ, not dd
    }

    func testDoubledVowelsAndWStayLiteralInVNI() {
        XCTAssertEqual(vni("oo"), "oo")
        XCTAssertEqual(vni("aa"), "aa")
        XCTAssertEqual(vni("ee"), "ee")
        XCTAssertEqual(vni("xoong"), "xoong")   // real VN word; must NOT become xông
        XCTAssertEqual(vni("book"), "book")      // English; double-o stays literal
        XCTAssertEqual(vni("w"), "w")            // literal w, not ư
        XCTAssertEqual(vni("uw"), "uw")          // stays literal, not ư
    }
}
