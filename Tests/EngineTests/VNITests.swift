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
}
