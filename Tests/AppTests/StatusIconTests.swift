import AppKit
import XCTest
@testable import dkey

/// StatusIcon vẽ icon menu bar theo mkey: nền tô đặc, chữ V/E.
final class StatusIconTests: XCTestCase {
    private func srgb(_ c: NSColor) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let n = c.usingColorSpace(.sRGB)!
        return (n.redComponent, n.greenComponent, n.blueComponent)
    }

    func testLetterVietnamese() {
        XCTAssertEqual(StatusIcon.letter(vietnamese: true), "V")
    }

    func testLetterEnglish() {
        XCTAssertEqual(StatusIcon.letter(vietnamese: false), "E")
    }

    // Chế độ màu: nền xanh #0066AB (khớp mkey StatusIcon).
    func testColorFillIsBrandBlue() {
        let (r, g, b) = srgb(StatusIcon.fillColor(gray: false))
        XCTAssertEqual(r, 0x00 / 255, accuracy: 0.01)
        XCTAssertEqual(g, 0x66 / 255, accuracy: 0.01)
        XCTAssertEqual(b, 0xAB / 255, accuracy: 0.01)
    }

    // Chế độ đơn sắc (template): nền đen để hệ thống tô lại theo menu bar.
    func testGrayFillIsBlack() {
        let (r, g, b) = srgb(StatusIcon.fillColor(gray: true))
        XCTAssertEqual(r, 0, accuracy: 0.01)
        XCTAssertEqual(g, 0, accuracy: 0.01)
        XCTAssertEqual(b, 0, accuracy: 0.01)
    }

    // Icon đơn sắc phải là template để đổi màu theo menu bar sáng/tối.
    func testTemplateFlagMatchesGray() {
        XCTAssertTrue(StatusIcon.image(vietnamese: true, gray: true).isTemplate)
        XCTAssertFalse(StatusIcon.image(vietnamese: true, gray: false).isTemplate)
    }

    func testImageSize() {
        let img = StatusIcon.image(vietnamese: true, gray: false)
        XCTAssertEqual(img.size.width, 18)
        XCTAssertEqual(img.size.height, 18)
    }
}
