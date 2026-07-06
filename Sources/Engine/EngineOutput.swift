import Foundation

/// Describes how the Phase-2 event-tap consumer should handle an EngineOutput.
///
/// Contract (must be respected by every return path in TelexEngine):
/// - `.process`     — engine consumed the key and applied a Vietnamese transform
///                    (diacritic add, circumflex, horn, đ, tone re-place).
///                    Consumer applies `backspaceCount` + `newChars` and swallows the key.
/// - `.restore`     — engine consumed the key and UNDID a diacritic/tone (toggle-off).
///                    The self-contained engine model includes the trigger key in `newChars`,
///                    so the consumer applies `backspaceCount` + `newChars` and swallows the key.
/// - `.passthrough` — engine made no Vietnamese transform; `newChars` carries the literal
///                    typed character (plain insert). Consumer emits the key normally.
/// - `.wordBreak`   — word boundary (space, punctuation, etc.). Consumer resets session.
public enum Action: Equatable { case passthrough, process, wordBreak, restore }

public struct EngineOutput: Equatable {
    public let backspaceCount: Int
    public let newChars: [Unicode.Scalar]
    public let action: Action
    public init(backspaceCount: Int, newChars: [Unicode.Scalar], action: Action) {
        self.backspaceCount = backspaceCount; self.newChars = newChars; self.action = action
    }
    public static let none = EngineOutput(backspaceCount: 0, newChars: [], action: .passthrough)
}

public protocol InputEngine: AnyObject {
    func handle(key: UInt16, caps: Bool) -> EngineOutput
    func backspace() -> EngineOutput
    func newSession()
    var useModernOrthography: Bool { get set }
    var inputMethod: InputMethod { get set }
}
