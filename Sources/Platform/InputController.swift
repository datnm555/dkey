import Foundation

/// Pure decision core: turns a KeyEvent into a SynthesisPlan. No CGEvent here.
public final class InputController {
    public let engine: TelexEngine
    public var isVietnamese: Bool
    public var switchKeyStatus: Int32
    public let macro = MacroExpander()
    public var useMacroInEnglishMode = false
    public var onLanguageChanged: ((Bool) -> Void)?

    public init(engine: TelexEngine = TelexEngine(),
                isVietnamese: Bool = true,
                switchKeyStatus: Int32 = 0x7A000206) {
        self.engine = engine
        self.isVietnamese = isVietnamese
        self.switchKeyStatus = switchKeyStatus
    }

    public func setVietnamese(_ on: Bool) {
        isVietnamese = on
        engine.newSession()
        macro.reset()
    }

    public func apply(inputMethod: InputMethod, modernOrthography: Bool, switchKeyStatus: Int32) {
        engine.inputMethod = inputMethod
        engine.useModernOrthography = modernOrthography
        self.switchKeyStatus = switchKeyStatus
        engine.newSession()
        macro.reset()
    }

    /// True while macro expansion is permitted for the current language state.
    private var macroActive: Bool { macro.isEnabled && (isVietnamese || useMacroInEnglishMode) }

    public func handle(_ e: KeyEvent) -> SynthesisPlan {
        switch e.kind {
        case .flagsChanged, .keyUp: return .passthrough
        case .keyDown: break
        }
        // 1. Hotkey.
        if HotkeyMatcher.matches(status: switchKeyStatus, keyCode: e.keyCode, flags: e.flags) {
            isVietnamese.toggle(); engine.newSession(); macro.reset()
            onLanguageChanged?(isVietnamese)
            return .toggleLanguage
        }
        // 2. Control/command shortcut → break the word, pass through.
        if e.hasOtherControl {
            if isVietnamese { engine.newSession() }  // gated: original code never called engine in English mode
            macro.reset()
            return .passthrough
        }

        // 3. Backspace (only intercepted when macro is active — otherwise behaviour is 100%
        //    unchanged). Keep the macro word in sync and pass through. We deliberately do NOT wire
        //    engine.backspace() (it has no callers today; adding backspace re-placement is out of
        //    scope for this feature). When macro is off, Delete falls through to the existing path.
        if macroActive && e.keyCode == KeyCode.delete {
            macro.apply(backspaces: 1, chars: [])
            return .passthrough
        }

        // 4. Word-break key: try macro expansion first.
        if TelexEngine.breakCodes.contains(e.keyCode) {
            if macroActive, let (bs, content) = macro.expand(), let brk = Self.breakScalar(for: e.keyCode, caps: e.caps) {
                macro.reset(); engine.newSession()
                return .consume(backspaces: bs, chars: content + [brk])
            }
            macro.reset()
            if isVietnamese { engine.newSession() }
            return .passthrough
        }

        // 5. Normal key.
        if !isVietnamese {
            // English mode: track the literal char for macro; pass the key through.
            if macroActive, let scalar = Self.literalScalar(keyCode: e.keyCode, caps: e.caps) {
                macro.apply(backspaces: 0, chars: [scalar])
            }
            return .passthrough
        }
        let out = engine.handle(key: e.keyCode, caps: e.caps)
        if macroActive { macro.apply(backspaces: out.backspaceCount, chars: out.newChars) }
        switch out.action {
        case .passthrough, .wordBreak: return .passthrough
        case .process, .restore: return .consume(backspaces: out.backspaceCount, chars: out.newChars)
        }
    }

    /// The scalar a printable break key inserts (space/enter/tab + punctuation), else nil.
    static func breakScalar(for keyCode: UInt16, caps: Bool) -> Unicode.Scalar? {
        switch keyCode {
        case KeyCode.space: return " "
        case KeyCode.enter, KeyCode.ret: return "\n"
        case KeyCode.tab: return "\t"
        case KeyCode.comma:     return caps ? "<" : ","
        case KeyCode.dot:       return caps ? ">" : "."
        case KeyCode.semicolon: return caps ? ":" : ";"
        case KeyCode.quote:     return caps ? "\"" : "'"
        case KeyCode.slash:     return caps ? "?" : "/"
        case KeyCode.backSlash: return caps ? "|" : "\\"
        case KeyCode.minus:     return caps ? "_" : "-"
        case KeyCode.equals:    return caps ? "+" : "="
        case KeyCode.backquote: return caps ? "~" : "`"
        default: return literalScalar(keyCode: keyCode, caps: caps)  // arrows/esc → nil → reset without expanding
        }
    }

    /// ASCII scalar for a keyCode (letters/digits/basic punctuation via keyCodeToCharacter), else nil.
    static func literalScalar(keyCode: UInt16, caps: Bool) -> Unicode.Scalar? {
        let cell = UInt32(keyCode) | (caps ? EngineMask.caps : 0)
        let ascii = keyCodeToCharacter(cell)
        return ascii != 0 ? Unicode.Scalar(ascii) : nil
    }
}
