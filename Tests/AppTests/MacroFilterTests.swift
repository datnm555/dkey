import XCTest
@testable import dkey

final class MacroFilterTests: XCTestCase {
    private let sample = [
        Macro(key: "vn", content: "Việt Nam"),
        Macro(key: "kg", content: "Kính gửi Anh/Chị,"),
        Macro(key: "dc", content: "được"),
    ]

    func testEmptyOrWhitespaceQueryReturnsAll() {
        XCTAssertEqual(MacroFilter.filter(sample, query: ""), sample)
        XCTAssertEqual(MacroFilter.filter(sample, query: "   "), sample)
    }

    func testMatchByKeyCaseInsensitive() {
        XCTAssertEqual(MacroFilter.filter(sample, query: "VN").map(\.key), ["vn"])
    }

    func testMatchByContentCaseInsensitive() {
        XCTAssertEqual(MacroFilter.filter(sample, query: "gửi").map(\.key), ["kg"])
    }

    func testNoMatchReturnsEmpty() {
        XCTAssertTrue(MacroFilter.filter(sample, query: "zzz").isEmpty)
    }

    func testPreservesOriginalOrder() {
        XCTAssertEqual(MacroFilter.filter(sample, query: "").map(\.key), ["vn", "kg", "dc"])
    }
}
