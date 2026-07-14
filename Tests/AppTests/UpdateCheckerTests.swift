import XCTest
@testable import dkey

/// So sánh phiên bản (semver) cho UpdateChecker — logic thuần, không mạng.
final class UpdateCheckerTests: XCTestCase {
    func testNewerPatch() {
        XCTAssertTrue(UpdateChecker.isNewer("1.3.10", than: "1.3.9"))
    }

    func testNewerMinorAndMajor() {
        XCTAssertTrue(UpdateChecker.isNewer("1.4.0", than: "1.3.9"))
        XCTAssertTrue(UpdateChecker.isNewer("2.0.0", than: "1.9.9"))
    }

    func testEqualIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("1.3.0", than: "1.3.0"))
    }

    func testOlderIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("1.3.0", than: "1.10.0"))
    }

    func testBetaSuffixIsStripped() {
        XCTAssertEqual(UpdateChecker.numericComponents("1.4.0-beta"), [1, 4, 0])
    }

    func testLeadingVIgnoredByComponents() {
        // "v" bị loại khi tách; chuỗi rỗng phần số → không coi là mới (tránh báo nhầm).
        XCTAssertEqual(UpdateChecker.numericComponents("v1.2"), [1, 2])
    }

    func testGarbageNeverNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("", than: "1.0.0"))
        XCTAssertFalse(UpdateChecker.isNewer("abc", than: "1.0.0"))
    }
}
