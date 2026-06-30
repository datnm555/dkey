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
        // OpenKey caps-quirk: insertW's "th" branch matches only LOWERCASE "th" (exact cell
        // compare incl. the caps bit, Engine.cpp:900-911), so the th-branch horns just 'o'
        // (→ "thuơ"), while capitalized "Th" falls to the default branch and horns BOTH
        // vowels (→ "Thươ"). Observable only before a following consonant.
        XCTAssertEqual(type("thuow"), "thuơ")
        XCTAssertEqual(type("Thuow"), "Thươ")
        // Once a following consonant (n/c/i/m/p/t) appears, checkGrammar's UO re-flow
        // (Engine.cpp:302-317) horns BOTH vowels for the lowercase case too → "thương".
        // Confirmed by the OpenKey oracle (parity corpus: thuowng → "thương").
        // (The previous expectation "thuơng" predated per-key checkGrammar and contradicted
        // the C++ reference.)
        XCTAssertEqual(type("thuowng"), "thương")
        XCTAssertEqual(type("Thuowng"), "Thương")
    }
    func testStandaloneTables() {
        XCTAssertEqual(type("ngw"), "ngư")  // "ng" in doubleWAllowed → standalone ư
        XCTAssertEqual(type("fw"), "fw")    // 'f' in standaloneWbad → w not converted
    }
}
