import Foundation

/// One text-expansion shortcut: type `key`, get `content`.
public struct Macro: Codable, Equatable, Identifiable {
    public var key: String
    public var content: String
    public var id: String { key }
    public init(key: String, content: String) { self.key = key; self.content = content }
}
