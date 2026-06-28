import Foundation

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
}
