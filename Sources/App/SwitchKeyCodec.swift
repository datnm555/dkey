import Foundation

/// Encodes a captured shortcut into the switchKeyStatus bitfield understood by
/// HotkeyMatcher and AppState.hotkeyDescription:
///   byte low (&0xFF) = keyCode, 0x100/200/400/800 = ⌃/⌥/⌘/⇧, byte high (>>24) = display ASCII.
enum SwitchKeyCodec {
    static func encode(keyCode: UInt16, displayASCII: UInt8,
                       control: Bool, option: Bool, command: Bool, shift: Bool) -> Int32? {
        guard control || option || command || shift else { return nil }  // require a modifier
        var status: Int32 = Int32(displayASCII) << 24
        if control { status |= 0x100 }
        if option  { status |= 0x200 }
        if command { status |= 0x400 }
        if shift   { status |= 0x800 }
        status |= Int32(keyCode & 0xFF)
        return status
    }
}
