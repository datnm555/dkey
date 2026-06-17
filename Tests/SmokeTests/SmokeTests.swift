import XCTest
@testable import dkey

@MainActor
final class SmokeTests: XCTestCase {
    func testAppStateDefaults() {
        let state = AppState.shared
        XCTAssertTrue(state.isVietnamese)
        XCTAssertEqual(state.selectedPage, .typing)
        XCTAssertEqual(state.switchKeyStatus, AppState.defaultSwitchKeyStatus)
    }

    func testHotkeyDescriptionAltZ() {
        // 0x7A000206: display char 'Z' (0x7A ở byte cao... thực tế 0x7A là keycode,
        // display char nằm ở >>24). Kiểm tra option-bit (0x200) tạo ra "⌥".
        let desc = AppState.hotkeyDescription(0x00000200)
        XCTAssertEqual(desc, "⌥")
    }

    func testSettingsPagesCount() {
        XCTAssertEqual(SettingsPage.allCases.count, 5)
    }
}
