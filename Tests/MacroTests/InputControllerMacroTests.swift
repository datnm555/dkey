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

    func testExpandsAfterTelexTransform() {
        // Type "as" in Telex → displayed "á"; a macro keyed on the displayed char must match.
        let c = InputController()
        c.macro.isEnabled = true
        c.macro.setMacros([Macro(key: "á", content: "Anh")])
        _ = c.handle(down(KeyCode.a))          // 'a'
        _ = c.handle(down(KeyCode.s))          // Telex 's' → á (backspaces:1, chars:["á"])
        let plan = c.handle(down(KeyCode.space))
        XCTAssertEqual(plan, .consume(backspaces: 1, chars: Array("Anh ".unicodeScalars)))
    }

    func testDeleteKeepsMacroWordInSync() {
        let c = controller()   // macro "vn" → "Việt Nam", enabled
        _ = c.handle(down(KeyCode.v)); _ = c.handle(down(KeyCode.n))
        let delPlan = c.handle(down(KeyCode.delete))   // pops 'n' from the macro word
        XCTAssertEqual(delPlan, .passthrough)
        // Word is now "v" — not a macro — so space does NOT expand.
        XCTAssertEqual(c.handle(down(KeyCode.space)), .passthrough)
    }

    func testExpandsOnSemicolon() {
        let c = controller()
        _ = c.handle(down(KeyCode.v)); _ = c.handle(down(KeyCode.n))
        XCTAssertEqual(c.handle(down(KeyCode.semicolon)),
                       .consume(backspaces: 2, chars: Array("Việt Nam;".unicodeScalars)))
    }
}
