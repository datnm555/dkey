import XCTest
@testable import dkey

final class SettingsStoreTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "dkey.tests.\(UUID().uuidString)")!
        return d
    }

    func testDefaultsWhenEmpty() {
        let store = SettingsStore(defaults: freshDefaults())
        XCTAssertEqual(store.load(), DkeySettings.defaults)
    }

    func testRoundTrip() {
        let store = SettingsStore(defaults: freshDefaults())
        var s = DkeySettings.defaults
        s.inputMethod = .vni
        s.useModernOrthography = false
        s.switchKeyStatus = 0x7A000206
        s.isVietnamese = false
        s.useMacro = true
        s.useMacroInEnglishMode = true
        s.autoCapsMacro = true
        s.grayIcon = true
        s.showIconOnDock = true
        s.showUIOnStartup = true
        s.runOnStartup = true
        s.useSmartSwitchKey = true
        store.save(s)
        XCTAssertEqual(store.load(), s)
    }

    func testCorruptJSONFallsBackToDefaults() {
        let d = freshDefaults()
        d.set(Data("not json".utf8), forKey: "dkey.settings.v1")
        let store = SettingsStore(defaults: d)
        XCTAssertEqual(store.load(), DkeySettings.defaults)
    }

    @MainActor
    func testControllerApplyReachesEngine() {
        let c = InputController()
        c.apply(inputMethod: .vni, modernOrthography: false, switchKeyStatus: 0x7A000206)
        XCTAssertEqual(c.engine.inputMethod, .vni)
        XCTAssertFalse(c.engine.useModernOrthography)
        XCTAssertEqual(c.switchKeyStatus, 0x7A000206)
    }
}
