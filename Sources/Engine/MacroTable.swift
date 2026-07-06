import Foundation

/// Pure macro lookup with optional auto-capitalisation (port of Macro.cpp:findMacro semantics).
public struct MacroTable {
    private let byKey: [String: String]

    public init(_ macros: [Macro]) {
        var m: [String: String] = [:]
        for macro in macros where !macro.key.isEmpty { m[macro.key] = macro.content }
        byKey = m
    }

    /// Returns the expansion for `word`, or nil. With `autoCaps`, an all-lower stored key can
    /// still match a Cased trigger, casing the content to mirror the trigger.
    public func expansion(for word: String, autoCaps: Bool) -> String? {
        if let exact = byKey[word] { return exact }
        guard autoCaps, !word.isEmpty else { return nil }
        let lowerKey = word.lowercased()
        guard lowerKey != word, let content = byKey[lowerKey] else { return nil }

        let chars = Array(word)
        let firstUpper = chars[0].isUppercase
        guard firstUpper else { return nil }
        let secondUpper = chars.count > 1 && chars[1].isUppercase
        if firstUpper && secondUpper { return content.uppercased() }
        if firstUpper { return content.prefix(1).uppercased() + content.dropFirst() }
        return content
    }
}
