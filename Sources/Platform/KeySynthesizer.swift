import CoreGraphics

/// Synthesizes backspaces and Unicode insertions via a private event source.
/// The private source lets EventTap recognize and skip our own synthetic events.
final class KeySynthesizer {
    private let source: CGEventSource?
    let sourceStateID: Int64

    init() {
        let s = CGEventSource(stateID: .privateState)
        source = s
        sourceStateID = s.map { Int64($0.sourceStateID.rawValue) } ?? -1
    }

    func sendBackspaces(_ n: Int, proxy: CGEventTapProxy) {
        guard n > 0 else { return }
        for _ in 0..<n {
            post(keyCode: 51, proxy: proxy)     // 51 = Backspace/Delete
        }
    }

    /// Insert Unicode scalars as text. keyCode 0 + SetUnicodeString = "type this string".
    func sendUnicode(_ chars: [Unicode.Scalar], proxy: CGEventTapProxy) {
        guard !chars.isEmpty else { return }
        var utf16: [UniChar] = []
        for c in chars { utf16.append(contentsOf: Array(String(c).utf16)) }
        var offset = 0
        while offset < utf16.count {
            let slice = Array(utf16[offset..<min(offset + 16, utf16.count)])
            postUnicode(slice, proxy: proxy)
            offset += slice.count
        }
    }

    private func post(keyCode: CGKeyCode, proxy: CGEventTapProxy) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = [.maskNonCoalesced]; up.flags = [.maskNonCoalesced]
        down.tapPostEvent(proxy); up.tapPostEvent(proxy)
    }

    private func postUnicode(_ utf16: [UniChar], proxy: CGEventTapProxy) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }
        var buf = utf16
        down.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: &buf)
        up.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: &buf)
        down.tapPostEvent(proxy); up.tapPostEvent(proxy)
    }
}
