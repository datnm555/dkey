import Foundation

/// Tracks the currently-typed (displayed) word and expands it into macro content at a word break.
/// Pure logic — no CGEvent. Lives in InputController; fed the display delta of each key.
public final class MacroExpander {
    public var isEnabled = false
    public var autoCaps = false
    private var table = MacroTable([])
    private var word: [Character] = []

    public init() {}

    public func setMacros(_ macros: [Macro]) { table = MacroTable(macros) }

    /// Apply a key's display effect to the tracked word: delete `backspaces`, then append `chars`.
    public func apply(backspaces: Int, chars: [Unicode.Scalar]) {
        for _ in 0..<backspaces where !word.isEmpty { word.removeLast() }
        word.append(contentsOf: String(String.UnicodeScalarView(chars)))
    }

    /// If the tracked word is a macro, return (# chars to delete, expansion scalars). Caller resets after.
    public func expand() -> (backspaces: Int, content: [Unicode.Scalar])? {
        guard isEnabled, !word.isEmpty else { return nil }
        guard let content = table.expansion(for: String(word), autoCaps: autoCaps) else { return nil }
        return (word.count, Array(content.unicodeScalars))
    }

    public func reset() { word.removeAll(keepingCapacity: true) }
}
