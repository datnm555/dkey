import XCTest
@testable import dkey

final class SystemExtrasTests: XCTestCase {
    func testTwoRowsInMockupOrder() {
        XCTAssertEqual(SystemExtras.placeholderRows.map(\.title), [
            "Sửa lỗi autocorrect trên trình duyệt",
            "Ghi nhớ bảng mã theo ứng dụng",
        ])
    }

    func testAllRowsDisabled() {
        XCTAssertTrue(SystemExtras.placeholderRows.allSatisfy { !$0.enabled })
    }

    func testOnlySecondRowHasSubtitle() {
        let rows = SystemExtras.placeholderRows
        XCTAssertNil(rows[0].subtitle)
        XCTAssertEqual(rows[1].subtitle, "Hữu ích với Photoshop, CAD… dùng VNI, TCVN3")
    }
}
