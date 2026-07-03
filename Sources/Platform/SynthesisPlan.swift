import Foundation

/// What the event tap should do with a key, decided by InputController.
public enum SynthesisPlan: Equatable {
    case passthrough                                   // let the OS type the key
    case toggleLanguage                                // ⌥Z pressed; consume, flip VI/EN (already applied)
    case consume(backspaces: Int, chars: [Unicode.Scalar]) // consume; delete then insert
}
