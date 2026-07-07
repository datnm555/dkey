import XCTest
@testable import dkey

final class SmartSwitchTests: XCTestCase {
    private func fresh() -> UserDefaults { UserDefaults(suiteName: "dkey.tests.\(UUID().uuidString)")! }

    func testUnknownBundleReturnsNil() {
        XCTAssertNil(SmartSwitch(defaults: fresh()).languageFor("com.apple.Safari"))
    }

    func testRememberAndRecall() {
        let s = SmartSwitch(defaults: fresh())
        s.remember("com.apple.Safari", vietnamese: false)
        s.remember("com.apple.TextEdit", vietnamese: true)
        XCTAssertEqual(s.languageFor("com.apple.Safari"), false)
        XCTAssertEqual(s.languageFor("com.apple.TextEdit"), true)
    }

    func testEmptyBundleIgnored() {
        let s = SmartSwitch(defaults: fresh())
        s.remember("", vietnamese: true)
        XCTAssertNil(s.languageFor(""))
    }

    func testPersistRoundTrip() {
        let d = fresh()
        let a = SmartSwitch(defaults: d); a.remember("com.apple.Safari", vietnamese: false)
        XCTAssertEqual(SmartSwitch(defaults: d).languageFor("com.apple.Safari"), false)  // reload
    }

    func testReset() {
        let s = SmartSwitch(defaults: fresh())
        s.remember("com.apple.Safari", vietnamese: false); s.reset()
        XCTAssertNil(s.languageFor("com.apple.Safari"))
    }
}
