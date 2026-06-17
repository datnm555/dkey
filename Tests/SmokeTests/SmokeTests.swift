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

    func testHotkeyDescriptionModifierOnly() {
        // Chỉ bit ⌥ (0x200), không có ký tự hiển thị.
        XCTAssertEqual(AppState.hotkeyDescription(0x00000200), "⌥")
    }

    func testHotkeyDescriptionDefaultAltZ() {
        // Mặc định 0x7A000206: ⌥ (bit 0x200) + ký tự 'z' (byte cao 0x7A) → "⌥Z".
        // Bao phủ nhánh giải mã ký tự hiển thị (>>24).
        XCTAssertEqual(AppState.hotkeyDescription(AppState.defaultSwitchKeyStatus), "⌥Z")
    }

    func testSettingsPagesCount() {
        XCTAssertEqual(SettingsPage.allCases.count, 5)
    }
}
