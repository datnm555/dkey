import Foundation

/// One keyboard event, decoupled from CGEvent so the decision logic is testable.
public struct KeyEvent: Equatable {
    public enum Kind { case keyDown, keyUp, flagsChanged }
    public let keyCode: UInt16      // macOS virtual key code (same space as Engine KeyCode)
    public let caps: Bool           // shift or caps-lock active
    public let hasOtherControl: Bool // control / command / option / fn held (shift excluded)
    public let kind: Kind
    public let flags: UInt64        // raw CGEventFlags rawValue, for hotkey matching
    public init(keyCode: UInt16, caps: Bool, hasOtherControl: Bool, kind: Kind, flags: UInt64) {
        self.keyCode = keyCode; self.caps = caps; self.hasOtherControl = hasOtherControl
        self.kind = kind; self.flags = flags
    }
}
