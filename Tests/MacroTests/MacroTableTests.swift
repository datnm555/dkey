import XCTest
@testable import dkey

final class MacroTableTests: XCTestCase {
    private let table = MacroTable([
        Macro(key: "vn", content: "Việt Nam"),
        Macro(key: "btw", content: "by the way"),
    ])

    func testExactMatch() {
        XCTAssertEqual(table.expansion(for: "vn", autoCaps: false), "Việt Nam")
        XCTAssertEqual(table.expansion(for: "btw", autoCaps: false), "by the way")
    }

    func testNoMatch() {
        XCTAssertNil(table.expansion(for: "xyz", autoCaps: false))
        XCTAssertNil(table.expansion(for: "VN", autoCaps: false)) // no auto-caps → exact only
    }

    func testAutoCapsFirst() {
        XCTAssertEqual(table.expansion(for: "Btw", autoCaps: true), "By the way")
    }

    func testAutoCapsAll() {
        XCTAssertEqual(table.expansion(for: "BTW", autoCaps: true), "BY THE WAY")
    }

    func testAutoCapsLowerStillExact() {
        XCTAssertEqual(table.expansion(for: "btw", autoCaps: true), "by the way")
    }
}
