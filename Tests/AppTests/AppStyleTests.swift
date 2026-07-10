import XCTest
@testable import dkey

/// AppStyle chuẩn hoá kích thước dùng chung, khớp mkey AppStyle.
final class AppStyleTests: XCTestCase {
    func testContentMaxWidth() {
        XCTAssertEqual(AppStyle.contentMaxWidth, 680)
    }

    func testControlCornerRadius() {
        XCTAssertEqual(AppStyle.controlCornerRadius, 7)
    }

    func testCardCornerRadius() {
        XCTAssertEqual(AppStyle.cardCornerRadius, 8)
    }
}
