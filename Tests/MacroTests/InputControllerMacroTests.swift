import XCTest
@testable import dkey

final class InputControllerMacroTests: XCTestCase {
    private func controller(enMode: Bool = false) -> InputController {
        let c = InputController()
        c.macro.isEnabled = true
        c.macro.setMacros([Macro(key: "vn", content: "Việt Nam")])
        c.useMacroInEnglishMode = enMode
        return c
    }
    private func down(_ code: UInt16, caps: Bool = false) -> KeyEvent {
        KeyEvent(keyCode: code, caps: caps, hasOtherControl: false, kind: .keyDown, flags: 0)
    }

    func testExpandsOnSpace() {
        let c = controller()
        _ = c.handle(down(KeyCode.v)); _ = c.handle(down(KeyCode.n))
        let plan = c.handle(down(KeyCode.space))
        XCTAssertEqual(plan, .consume(backspaces: 2, chars: Array("Việt Nam ".unicodeScalars)))
    }

    func testNonMacroWordPassesThrough() {
        let c = controller()
        _ = c.handle(down(KeyCode.x)); _ = c.handle(down(KeyCode.y))
        XCTAssertEqual(c.handle(down(KeyCode.space)), .passthrough)
    }

    func testDisabledMacroNoExpand() {
        let c = controller(); c.macro.isEnabled = false
        _ = c.handle(down(KeyCode.v)); _ = c.handle(down(KeyCode.n))
        XCTAssertEqual(c.handle(down(KeyCode.space)), .passthrough)
    }

    func testEnglishModeExpandsWhenAllowed() {
        let c = controller(enMode: true); c.setVietnamese(false)
        _ = c.handle(down(KeyCode.v)); _ = c.handle(down(KeyCode.n))
        XCTAssertEqual(c.handle(down(KeyCode.space)), .consume(backspaces: 2, chars: Array("Việt Nam ".unicodeScalars)))
    }

    func testEnglishModeNoExpandWhenDisallowed() {
        let c = controller(enMode: false); c.setVietnamese(false)
        _ = c.handle(down(KeyCode.v)); _ = c.handle(down(KeyCode.n))
        XCTAssertEqual(c.handle(down(KeyCode.space)), .passthrough)
    }
}
