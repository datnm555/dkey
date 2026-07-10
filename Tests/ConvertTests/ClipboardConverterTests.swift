import AppKit
import XCTest
@testable import dkey

/// Chuyển mã qua clipboard: tách phần logic thuần khỏi I/O pasteboard để test.
final class ClipboardConverterTests: XCTestCase {
    func testNilInputGivesNil() {
        XCTAssertNil(ClipboardConverter.converted(nil, from: .unicode, to: .unicode,
                                                  caseMode: .keep, removeMark: false))
    }

    func testEmptyInputGivesNil() {
        XCTAssertNil(ClipboardConverter.converted("", from: .unicode, to: .unicode,
                                                  caseMode: .keep, removeMark: false))
    }

    func testUppercaseConversion() {
        XCTAssertEqual(
            ClipboardConverter.converted("abc", from: .unicode, to: .unicode,
                                         caseMode: .upper, removeMark: false),
            "ABC")
    }

    // Đọc/ghi trên một pasteboard riêng (không đụng clipboard hệ thống).
    func testConvertPasteboardRoundTrip() {
        let pb = NSPasteboard(name: NSPasteboard.Name("dkeyConvertTest"))
        pb.clearContents()
        pb.setString("abc", forType: .string)
        let ok = ClipboardConverter.convertPasteboard(from: .unicode, to: .unicode,
                                                      caseMode: .upper, removeMark: false,
                                                      pasteboard: pb)
        XCTAssertTrue(ok)
        XCTAssertEqual(pb.string(forType: .string), "ABC")
    }

    func testConvertPasteboardEmptyReturnsFalse() {
        let pb = NSPasteboard(name: NSPasteboard.Name("dkeyConvertTestEmpty"))
        pb.clearContents()
        let ok = ClipboardConverter.convertPasteboard(from: .unicode, to: .unicode,
                                                      caseMode: .keep, removeMark: false,
                                                      pasteboard: pb)
        XCTAssertFalse(ok)
    }
}
