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

    func testEmptyQueryReturnsFullListInOrder() {
        XCTAssertEqual(MacroFilter.filter(sample, query: "").map(\.key), ["vn", "kg", "dc"])
    }

    // Non-empty query that matches multiple rows: the filtered result must keep
    // the original relative order (exercises the filter body, not the passthrough).
    func testMatchesKeepOriginalRelativeOrder() {
        let macros = [
            Macro(key: "aa", content: "one match"),
            Macro(key: "bb", content: "no"),
            Macro(key: "ac", content: "another match"),
        ]
        XCTAssertEqual(MacroFilter.filter(macros, query: "match").map(\.key), ["aa", "ac"])
    }
}
