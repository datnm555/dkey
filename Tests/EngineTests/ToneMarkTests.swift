import XCTest
@testable import dkey

final class ToneMarkTests: XCTestCase {
    func testFiveTonesOnA() {
        XCTAssertEqual(type("as"), "á")
        XCTAssertEqual(type("af"), "à")
        XCTAssertEqual(type("ar"), "ả")
        XCTAssertEqual(type("ax"), "ã")
        XCTAssertEqual(type("aj"), "ạ")
    }
    func testToneOnConsonantWord() {
        XCTAssertEqual(type("toans"), "toán")
        XCTAssertEqual(type("hojc"), "học")
    }
    func testModernVsClassic() {
        XCTAssertEqual(type("hoaf", modern: true),  "hòa")
        XCTAssertEqual(type("hoaf", modern: false), "hoà")
        XCTAssertEqual(type("uys",  modern: true),  "úy")
        XCTAssertEqual(type("uys",  modern: false), "uý")
    }
    func testToggleOff() {
        // typing the mark key twice removes the tone (restore): "as" → á, second "s" → "as"
        XCTAssertEqual(type("ass"), "as")
    }
}
