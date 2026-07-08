import SwiftUI
import XCTest
@testable import dkey

final class ThemeTests: XCTestCase {
    private func rgb(_ c: Color) -> (r: Double, g: Double, b: Double) {
        let n = NSColor(c).usingColorSpace(.sRGB)!
        return (Double(n.redComponent), Double(n.greenComponent), Double(n.blueComponent))
    }

    func testHexInit() {
        let c = rgb(Color(hex: 0xFAF9F5))
        XCTAssertEqual(c.r, 0xFA/255, accuracy: 0.01)
        XCTAssertEqual(c.g, 0xF9/255, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xF5/255, accuracy: 0.01)
    }

    func testNamedAccent() {
        let c = rgb(Color.dkAccent)  // #5ba7f7
        XCTAssertEqual(c.r, 0x5B/255, accuracy: 0.01)
        XCTAssertEqual(c.g, 0xA7/255, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xF7/255, accuracy: 0.01)
    }
}
