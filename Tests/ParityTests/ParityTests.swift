import XCTest
@testable import dkey

final class ParityTests: XCTestCase {
    struct Row: Decodable { let input: String; let modern: String; let classic: String }

    func loadCorpus() throws -> [Row] {
        let url = Bundle(for: ParityTests.self).url(forResource: "parity-corpus", withExtension: "json")!
        return try JSONDecoder().decode([Row].self, from: Data(contentsOf: url))
    }

    func testParityModern() throws {
        var fails: [String] = []
        for row in try loadCorpus() {
            let got = type(row.input, modern: true)
            if got != row.modern {
                fails.append("\(row.input): got \(got) want \(row.modern)")
            }
        }
        XCTAssertTrue(fails.isEmpty, "modern parity failures (\(fails.count)):\n" + fails.prefix(40).joined(separator: "\n"))
    }

    func testParityClassic() throws {
        var fails: [String] = []
        for row in try loadCorpus() {
            let got = type(row.input, modern: false)
            if got != row.classic {
                fails.append("\(row.input): got \(got) want \(row.classic)")
            }
        }
        XCTAssertTrue(fails.isEmpty, "classic parity failures (\(fails.count)):\n" + fails.prefix(40).joined(separator: "\n"))
    }

    func loadVNICorpus() throws -> [Row] {
        let url = Bundle(for: ParityTests.self).url(forResource: "parity-corpus-vni", withExtension: "json")!
        return try JSONDecoder().decode([Row].self, from: Data(contentsOf: url))
    }

    func testVNIParityModern() throws {
        var fails: [String] = []
        for row in try loadVNICorpus() {
            let got = type(row.input, modern: true, method: .vni)
            if got != row.modern { fails.append("\(row.input): got \(got) want \(row.modern)") }
        }
        XCTAssertTrue(fails.isEmpty, "VNI modern failures (\(fails.count)):\n" + fails.prefix(40).joined(separator: "\n"))
    }

    func testVNIParityClassic() throws {
        var fails: [String] = []
        for row in try loadVNICorpus() {
            let got = type(row.input, modern: false, method: .vni)
            if got != row.classic { fails.append("\(row.input): got \(got) want \(row.classic)") }
        }
        XCTAssertTrue(fails.isEmpty, "VNI classic failures (\(fails.count)):\n" + fails.prefix(40).joined(separator: "\n"))
    }
}
