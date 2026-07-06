import XCTest
@testable import dkey

final class ConvertParityTests: XCTestCase {
    struct Row: Decodable { let from: Int; let to: Int; let text: String; let expected: String }

    func testConvertParity() throws {
        let url = Bundle(for: ConvertParityTests.self).url(forResource: "convert-corpus", withExtension: "json")!
        let rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: url))
        var fails: [String] = []
        for r in rows {
            // Corpus is generated in lower case-mode (the condition where dkey and OpenKey agree — see Task 3 note).
            let got = ConvertTool.convert(r.text, from: CodeTable(rawValue: r.from)!, to: CodeTable(rawValue: r.to)!, caseMode: .lower)
            if got != r.expected { fails.append("\(r.text) \(r.from)->\(r.to): got \(got) want \(r.expected)") }
        }
        XCTAssertTrue(fails.isEmpty, "convert parity failures (\(fails.count)):\n" + fails.prefix(40).joined(separator: "\n"))
    }
}
