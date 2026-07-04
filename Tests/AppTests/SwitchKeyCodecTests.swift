import XCTest
@testable import dkey

final class SwitchKeyCodecTests: XCTestCase {
    func testEncodeOptionZMatchesDefault() {
        // Z keyCode = 0x06, display 'z' = 0x7A, Option → 0x200.
        let status = SwitchKeyCodec.encode(keyCode: 0x06, displayASCII: 0x7A,
                                           control: false, option: true, command: false, shift: false)
        XCTAssertEqual(status, 0x7A000206)
    }

    func testEncodeControlShift() {
        let status = SwitchKeyCodec.encode(keyCode: 0x06, displayASCII: 0x7A,
                                           control: true, option: false, command: false, shift: true)
        XCTAssertEqual(status, Int32(0x7A000000 | 0x100 | 0x800 | 0x06))
    }

    func testRejectNoModifier() {
        XCTAssertNil(SwitchKeyCodec.encode(keyCode: 0x06, displayASCII: 0x7A,
                                           control: false, option: false, command: false, shift: false))
    }

    @MainActor
    func testRoundTripThroughHotkeyDescription() {
        let status = SwitchKeyCodec.encode(keyCode: 0x06, displayASCII: 0x7A,
                                           control: false, option: true, command: false, shift: false)!
        XCTAssertEqual(AppState.hotkeyDescription(status), "⌥Z")
    }
}
