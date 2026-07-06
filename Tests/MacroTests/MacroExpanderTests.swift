import XCTest
@testable import dkey

final class MacroExpanderTests: XCTestCase {
    private func expander() -> MacroExpander {
        let e = MacroExpander()
        e.isEnabled = true
        e.setMacros([Macro(key: "vn", content: "Việt Nam"), Macro(key: "btw", content: "by the way")])
        return e
    }

    private func type(_ s: String, into e: MacroExpander) {
        for ch in s { e.apply(backspaces: 0, chars: Array(String(ch).unicodeScalars)) }
    }

    func testExpandsOnMatch() {
        let e = expander(); type("vn", into: e)
        let hit = e.expand()
        XCTAssertEqual(hit?.backspaces, 2)
        XCTAssertEqual(String(String.UnicodeScalarView(hit?.content ?? [])), "Việt Nam")
    }

    func testNoMatchReturnsNil() {
        let e = expander(); type("xyz", into: e)
        XCTAssertNil(e.expand())
    }

    func testDisabledReturnsNil() {
        let e = expander(); e.isEnabled = false; type("vn", into: e)
        XCTAssertNil(e.expand())
    }

    func testAutoCaps() {
        let e = expander(); e.autoCaps = true; type("Btw", into: e)
        XCTAssertEqual(String(String.UnicodeScalarView(e.expand()?.content ?? [])), "By the way")
    }

    func testResetClearsWord() {
        let e = expander(); type("vn", into: e); e.reset()
        XCTAssertNil(e.expand())
    }

    func testBackspacePops() {
        let e = expander(); type("vno", into: e)
        e.apply(backspaces: 1, chars: [])   // delete the 'o'
        let hit = e.expand()
        XCTAssertEqual(hit?.backspaces, 2)
        XCTAssertEqual(String(String.UnicodeScalarView(hit?.content ?? [])), "Việt Nam")
    }
}
