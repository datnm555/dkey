import Foundation

/// Pure decision core: turns a KeyEvent into a SynthesisPlan. No CGEvent here.
/// Owns the Telex engine and the language state; the app layer keeps AppState in sync
/// via `onLanguageChanged` and `setVietnamese`.
public final class InputController {
    public let engine: TelexEngine
    public var isVietnamese: Bool
    public var switchKeyStatus: Int32
    /// Called (on the same thread as handle) whenever the language flips via the hotkey.
    public var onLanguageChanged: ((Bool) -> Void)?

    public init(engine: TelexEngine = TelexEngine(),
                isVietnamese: Bool = true,
                switchKeyStatus: Int32 = 0x7A000206) {
        self.engine = engine
        self.isVietnamese = isVietnamese
        self.switchKeyStatus = switchKeyStatus
    }

    /// UI-driven language change (menu toggle). Resets the engine session.
    public func setVietnamese(_ on: Bool) {
        isVietnamese = on
        engine.newSession()
    }

    public func handle(_ e: KeyEvent) -> SynthesisPlan {
        switch e.kind {
        case .flagsChanged, .keyUp:
            return .passthrough
        case .keyDown:
            break
        }
        // 1. Hotkey first (so ⌥Z is caught before the other-control passthrough).
        if HotkeyMatcher.matches(status: switchKeyStatus, keyCode: e.keyCode, flags: e.flags) {
            isVietnamese.toggle()
            engine.newSession()
            onLanguageChanged?(isVietnamese)
            return .toggleLanguage
        }
        // 2. English mode: never transform.
        if !isVietnamese { return .passthrough }
        // 3. A control/command/option shortcut breaks the word and passes through.
        if e.hasOtherControl {
            engine.newSession()
            return .passthrough
        }
        // 4. Feed the engine; map the action contract to a plan.
        let out = engine.handle(key: e.keyCode, caps: e.caps)
        switch out.action {
        case .passthrough, .wordBreak:
            return .passthrough
        case .process, .restore:
            return .consume(backspaces: out.backspaceCount, chars: out.newChars)
        }
    }
}
