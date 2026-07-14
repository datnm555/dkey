import Carbon.HIToolbox
import XCTest
@testable import dkey

/// Giải mã bitfield hotkey → cờ Carbon (thuần, không đăng ký hệ thống).
final class GlobalHotKeyTests: XCTestCase {
    func testControlModifier() {
        XCTAssertEqual(GlobalHotKey.carbonModifiers(from: 0x100), UInt32(controlKey))
    }

    func testOptionModifier() {
        XCTAssertEqual(GlobalHotKey.carbonModifiers(from: 0x200), UInt32(optionKey))
    }

    func testCommandModifier() {
        XCTAssertEqual(GlobalHotKey.carbonModifiers(from: 0x400), UInt32(cmdKey))
    }

    func testShiftModifier() {
        XCTAssertEqual(GlobalHotKey.carbonModifiers(from: 0x800), UInt32(shiftKey))
    }

    func testCombinedModifiers() {
        let m = GlobalHotKey.carbonModifiers(from: 0x100 | 0x400)
        XCTAssertEqual(m, UInt32(controlKey) | UInt32(cmdKey))
    }

    func testKeyCodeIsLowByte() {
        // ⌃V mặc định 0x7600_0109 → keycode V = 0x09.
        XCTAssertEqual(GlobalHotKey.keyCode(from: 0x7600_0109), 0x09)
    }

    func testDefaultHotKeyIsControlV() {
        XCTAssertEqual(GlobalHotKey.keyCode(from: ClipboardManager.defaultHotKey), UInt32(kVK_ANSI_V))
        XCTAssertEqual(GlobalHotKey.carbonModifiers(from: ClipboardManager.defaultHotKey), UInt32(controlKey))
    }
}
