import XCTest
@testable import dkey

final class RemoveAndBackspaceTests: XCTestCase {
    func testZRemovesTone() {
        // 'a' + sắc (s) → á, then z removes tone mark → a
        XCTAssertEqual(type("asz"), "a")
        // 'a' + circumflex (aa) + sắc (s) → ấ, then z removes only tone mark (keeps â)
        XCTAssertEqual(type("aasz"), "â")
    }

    func testBackspaceReplacement() {
        // "hoaf" → "hòa" (grave on 'o', 'a' appended); one backspace removes 'a' → "hò"
        // C++ oracle: checkGrammar(1) finds mark2 on 'o', re-places it at same position
        // (single-vowel cluster after deletion), so mark doesn't move → just delete 1 char.
        XCTAssertEqual(type("hoaf\u{8}"), "hò")
    }
}
