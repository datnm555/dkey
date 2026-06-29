import XCTest
@testable import dkey

/// End-to-end regression suite using real Vietnamese Telex inputs.
/// Every expected value is derived from the OpenKey C++ oracle
/// (scripts/openkey-oracle/oracle). If a Swift-engine result diverges
/// from these values, that is an engine bug — do NOT change the expected
/// string; report the divergence instead.
final class CuratedTelexTests: XCTestCase {

    // MARK: – Modern orthography (default)

    func testCommonWords() {
        // (input, oracle-modern-output)
        let cases: [(String, String)] = [
            ("tieesng",  "tiếng"),   // oracle: tiếng
            ("vieejt",   "việt"),    // oracle: việt
            ("nam",      "nam"),     // oracle: nam
            ("ddaay",    "đây"),     // oracle: đây
            ("quoocs",   "quốc"),    // oracle: quốc
            ("hojc",     "học"),     // oracle: học
            ("nguwowif", "người"),   // oracle: người
            ("trraan",   "trrân"),   // oracle: trrân  (not spell-checked in Phase 1)
            ("xin",      "xin"),     // oracle: xin
            ("chaof",    "chào"),    // oracle: chào
            ("ddoongf",  "đồng"),    // oracle: đồng
            ("thuyr",    "thủy"),    // oracle: thủy  (modern placement)
            ("vaf",      "và"),      // oracle: và
            ("ddi",      "đi"),      // oracle: đi
        ]
        for (input, expected) in cases {
            XCTAssertEqual(type(input), expected, "input=\(input)")
        }
    }

    // MARK: – Modern vs Classic placement

    func testModernVsClassic() {
        // hoaf: modern → hòa (tone on oa nucleus), classic → hoà (tone on a)
        XCTAssertEqual(type("hoaf", modern: true),  "hòa",  "hoaf modern")
        XCTAssertEqual(type("hoaf", modern: false), "hoà",  "hoaf classic")

        // thuys: modern → thúy, classic → thuý
        XCTAssertEqual(type("thuys", modern: true),  "thúy", "thuys modern")
        XCTAssertEqual(type("thuys", modern: false), "thuý", "thuys classic")

        // thuyr: modern → thủy, classic → thuỷ
        XCTAssertEqual(type("thuyr", modern: true),  "thủy", "thuyr modern")
        XCTAssertEqual(type("thuyr", modern: false), "thuỷ", "thuyr classic")
    }
}
