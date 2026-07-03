import XCTest
import CoreGraphics
@testable import dkey

final class InputControllerTests: XCTestCase {
    private func keyDown(_ ch: Character, control: Bool = false, flags: UInt64 = 0) -> KeyEvent {
        let (code, caps) = KeyCode.keyCode(for: ch)!
        return KeyEvent(keyCode: code, caps: caps, hasOtherControl: control, kind: .keyDown, flags: flags)
    }

    func testVietnameseTransform() {
        let c = InputController()                       // VI on by default
        XCTAssertEqual(c.handle(keyDown("a")), .passthrough)          // plain letter → OS types it
        XCTAssertEqual(c.handle(keyDown("s")), .consume(backspaces: 1, chars: ["á"]))
    }
    func testWordBreakPassthrough() {
        let c = InputController()
        _ = c.handle(keyDown("a"))
        XCTAssertEqual(c.handle(keyDown(" ")), .passthrough)          // space → wordBreak → passthrough
    }
    func testHotkeyTogglesLanguage() {
        let c = InputController()
        var notified: Bool?
        c.onLanguageChanged = { notified = $0 }
        let z = KeyEvent(keyCode: 6, caps: false, hasOtherControl: true,
                         kind: .keyDown, flags: CGEventFlags.maskAlternate.rawValue)
        XCTAssertEqual(c.handle(z), .toggleLanguage)
        XCTAssertFalse(c.isVietnamese)
        XCTAssertEqual(notified, false)
    }
    func testEnglishModePassthrough() {
        let c = InputController(isVietnamese: false)
        XCTAssertEqual(c.handle(keyDown("a")), .passthrough)
        XCTAssertEqual(c.handle(keyDown("s")), .passthrough)          // no transform in EN
    }
    func testOtherControlPassthrough() {
        let c = InputController()
        _ = c.handle(keyDown("a"))
        XCTAssertEqual(c.handle(keyDown("c", control: true)), .passthrough) // ⌘C not transformed
    }
    func testFlagsChangedAndKeyUpPassthrough() {
        let c = InputController()
        XCTAssertEqual(c.handle(KeyEvent(keyCode: 6, caps: false, hasOtherControl: true,
                                         kind: .flagsChanged, flags: 0)), .passthrough)
        XCTAssertEqual(c.handle(KeyEvent(keyCode: 1, caps: false, hasOtherControl: false,
                                         kind: .keyUp, flags: 0)), .passthrough)
    }
    func testDiphthongToneMovesCorrectly() {
        let c = InputController()
        _ = c.handle(keyDown("h")); _ = c.handle(keyDown("o")); _ = c.handle(keyDown("a"))
        let plan = c.handle(keyDown("f"))                            // hoa + f → hòa
        XCTAssertEqual(plan, .consume(backspaces: 2, chars: ["ò", "a"]))
    }
}
