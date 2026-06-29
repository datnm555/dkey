import XCTest
@testable import dkey

final class HornTests: XCTestCase {
    func testHorn() {
        XCTAssertEqual(type("uw"), "ư")
        XCTAssertEqual(type("ow"), "ơ")
        XCTAssertEqual(type("aw"), "ă")
    }
    func testStandaloneW() { XCTAssertEqual(type("w"), "ư") }
    func testBrackets() {
        XCTAssertEqual(type("["), "ơ")
        XCTAssertEqual(type("]"), "ư")
    }
    func testHornWord() {
        XCTAssertEqual(type("uowng"), "ương")  // ư + ơ + ng
        // NOTE: dduowngf ("đường") is deferred to Task 9 (requires insertD for đ via dd)
    }
}
