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

    func testApplicableLanguageDisabledReturnsNil() {
        let s = SmartSwitch(defaults: fresh()); s.remember("a", vietnamese: false)
        s.isEnabled = false
        XCTAssertNil(s.applicableLanguage(for: "a", current: true))
    }
    func testApplicableLanguageUnknownOrSameReturnsNil() {
        let s = SmartSwitch(defaults: fresh()); s.isEnabled = true
        XCTAssertNil(s.applicableLanguage(for: "unknown", current: true))
        s.remember("a", vietnamese: true)
        XCTAssertNil(s.applicableLanguage(for: "a", current: true))   // already matches
    }
    func testApplicableLanguageDifferentReturnsRemembered() {
        let s = SmartSwitch(defaults: fresh()); s.isEnabled = true
        s.remember("a", vietnamese: false)
        XCTAssertEqual(s.applicableLanguage(for: "a", current: true), false)
    }
    func testRecordIfEnabledRespectsFlag() {
        let s = SmartSwitch(defaults: fresh())
        s.isEnabled = false; s.recordIfEnabled("a", vietnamese: true)
        XCTAssertNil(s.languageFor("a"))
        s.isEnabled = true; s.recordIfEnabled("a", vietnamese: true)
        XCTAssertEqual(s.languageFor("a"), true)
    }
}
