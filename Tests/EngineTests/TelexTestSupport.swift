import XCTest
@testable import dkey

/// Drive the engine from an ASCII Telex string; return the resulting text.
/// Applies backspaceCount + newChars to a mutable [Character] buffer per key.
func type(_ telex: String, modern: Bool = true, method: InputMethod = .telex, engine: TelexEngine? = nil) -> String {
    let e = engine ?? TelexEngine()
    e.useModernOrthography = modern
    e.inputMethod = method
    e.newSession()
    var screen: [Character] = []
    for ch in telex {
        // Backspace sentinel: U+0008 (BS control character) → call engine.backspace()
        if ch == "\u{8}" {
            let out = e.backspace()
            for _ in 0..<out.backspaceCount { if !screen.isEmpty { screen.removeLast() } }
            for s in out.newChars { screen.append(Character(s)) }
            continue
        }
        guard let (code, caps) = KeyCode.keyCode(for: ch) else { continue }
        let out = e.handle(key: code, caps: caps)
        if out.action == .wordBreak {
            // space/punctuation: append the literal then reset visual word boundary tracking
            screen.append(ch)
            continue
        }
        for _ in 0..<out.backspaceCount { if !screen.isEmpty { screen.removeLast() } }
        for s in out.newChars { screen.append(Character(s)) }
    }
    return String(screen)
}
