import XCTest
@testable import dkey

final class DTests: XCTestCase {
    func testDBar() {
        XCTAssertEqual(type("dd"), "đ")
        XCTAssertEqual(type("ddaf"), "đà")
        XCTAssertEqual(type("dduowngf"), "đường")
    }
    func testDRestore() { XCTAssertEqual(type("ddd"), "dd") } // third d restores
}
