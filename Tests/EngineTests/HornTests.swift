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
    func testThQCapsSensitivity() {
        // OpenKey caps-quirk: capitalized "Th"+uo horns BOTH vowels → "Thương"
        XCTAssertEqual(type("Thuowng"), "Thương")
        // lowercase keeps th-branch (horn on o only) → "thuơng"
        XCTAssertEqual(type("thuowng"), "thuơng")
    }
    func testStandaloneTables() {
        XCTAssertEqual(type("ngw"), "ngư")  // "ng" in doubleWAllowed → standalone ư
        XCTAssertEqual(type("fw"), "fw")    // 'f' in standaloneWbad → w not converted
    }
}
