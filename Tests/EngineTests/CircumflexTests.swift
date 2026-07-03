import XCTest
@testable import dkey

final class CircumflexTests: XCTestCase {
    func testCircumflex() {
        XCTAssertEqual(type("aa"), "â")
        XCTAssertEqual(type("ee"), "ê")
        XCTAssertEqual(type("oo"), "ô")
    }
    func testCircumflexWithTone() {
        XCTAssertEqual(type("aas"), "ấ")
        XCTAssertEqual(type("oojc"), "ộc")   // ô + nặng + c
    }
    func testRestoreOnThird() {
        XCTAssertEqual(type("aaa"), "aa")    // third a removes circumflex
    }
}
