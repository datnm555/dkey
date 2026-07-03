import XCTest
@testable import dkey

final class PlatformValueTypesTests: XCTestCase {
    func testKeyEventEquatable() {
        let a = KeyEvent(keyCode: 1, caps: false, hasOtherControl: false, kind: .keyDown, flags: 0)
        let b = KeyEvent(keyCode: 1, caps: false, hasOtherControl: false, kind: .keyDown, flags: 0)
        XCTAssertEqual(a, b)
    }
    func testSynthesisPlanEquatable() {
        XCTAssertEqual(SynthesisPlan.consume(backspaces: 1, chars: ["á"]),
                       SynthesisPlan.consume(backspaces: 1, chars: ["á"]))
        XCTAssertNotEqual(SynthesisPlan.passthrough, SynthesisPlan.toggleLanguage)
    }
}
