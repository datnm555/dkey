import XCTest
@testable import dkey

final class TypingExtrasTests: XCTestCase {
    func testFiveRowsInMockupOrder() {
        XCTAssertEqual(TypingExtras.placeholderRows.map(\.title), [
            "Kiểm tra chính tả",
            "Khôi phục phím nếu từ sai",
            "Viết hoa chữ cái đầu câu",
            "Gõ nhanh Telex",
            "Cho phép f, z, w, j làm phụ âm đầu",
        ])
    }

    func testAllRowsDisabled() {
        XCTAssertTrue(TypingExtras.placeholderRows.allSatisfy { !$0.enabled })
    }

    func testOnlyQuickTelexHasSubtitle() {
        let rows = TypingExtras.placeholderRows
        XCTAssertEqual(rows[3].subtitle, "cc = ch, gg = gi, kk = kh, nn = ng…")
        let others = rows.enumerated().filter { $0.offset != 3 }.map(\.element)
        XCTAssertTrue(others.allSatisfy { $0.subtitle == nil })
    }
}
