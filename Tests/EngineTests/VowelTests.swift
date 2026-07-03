import XCTest
@testable import dkey

final class VowelTests: XCTestCase {
    private func vowelInfo(_ telex: String) -> (start: Int, end: Int, count: Int) {
        let e = TelexEngine()
        for ch in telex { let (c, caps) = KeyCode.keyCode(for: ch)!; _ = e.handle(key: c, caps: caps) }
        e.findAndCalculateVowel(forGrammar: false)
        return (e.vowelStartIndex, e.vowelEndIndex, e.vowelCount)
    }

    func testSingleVowel() {
        let v = vowelInfo("ba")            // b-a: one vowel at index 1
        XCTAssertEqual(v.count, 1)
        XCTAssertEqual(v.start, 1)
    }

    func testDiphthong() {
        let v = vowelInfo("hoa")           // h-o-a: two vowels at indices 1-2
        XCTAssertEqual(v.count, 2)
        XCTAssertEqual(v.start, 1)
        XCTAssertEqual(v.end, 2)
    }

    func testTriphthong() {
        let v = vowelInfo("oai")           // o-a-i: three vowels at indices 0-2
        XCTAssertEqual(v.count, 3)
    }
}
