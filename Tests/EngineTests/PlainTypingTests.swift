import XCTest
@testable import dkey

final class PlainTypingTests: XCTestCase {
    func testPlainAscii() { XCTAssertEqual(type("abc"), "abc") }
    func testConsonantCluster() { XCTAssertEqual(type("ngh"), "ngh") }
    func testNewSessionOnSpace() { XCTAssertEqual(type("ab cd"), "ab cd") }
}
