import XCTest
import CoreGraphics
@testable import dkey

final class HotkeyMatcherTests: XCTestCase {
    let altZ: Int32 = 0x7A000206   // ⌥Z: keyCode 0x06 (KEY_Z), option bit 0x200
    let optionOnly = CGEventFlags.maskAlternate.rawValue

    func testMatchesAltZ() {
        XCTAssertTrue(HotkeyMatcher.matches(status: altZ, keyCode: 6, flags: optionOnly))
    }
    func testWrongKey() {
        XCTAssertFalse(HotkeyMatcher.matches(status: altZ, keyCode: 1, flags: optionOnly))
    }
    func testMissingOption() {
        XCTAssertFalse(HotkeyMatcher.matches(status: altZ, keyCode: 6, flags: 0))
    }
    func testExtraCommandRejected() {
        let optCmd = (CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue)
        XCTAssertFalse(HotkeyMatcher.matches(status: altZ, keyCode: 6, flags: optCmd))
    }
}
