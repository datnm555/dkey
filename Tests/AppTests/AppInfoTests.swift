import XCTest
@testable import dkey

final class AppInfoTests: XCTestCase {
    func testFormatsShortAndBuild() {
        let info: [String: Any] = ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1"]
        XCTAssertEqual(AppInfo.versionString(from: info), "0.1.0 (1)")
    }

    func testFallbackWhenNil() {
        XCTAssertEqual(AppInfo.versionString(from: nil), "—")
    }

    func testFallbackWhenMissingKeys() {
        XCTAssertEqual(AppInfo.versionString(from: ["CFBundleShortVersionString": "0.1.0"]), "—")
        XCTAssertEqual(AppInfo.versionString(from: [:]), "—")
    }
}
