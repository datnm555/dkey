import CoreGraphics

/// Matches the switch-key bitfield (e.g. ⌥Z = 0x7A000206) against a physical key event.
enum HotkeyMatcher {
    static func matches(status: Int32, keyCode: UInt16, flags: UInt64) -> Bool {
        let wantKey = UInt16(status & 0xFF)
        if wantKey == 0 || keyCode != wantKey { return false }
        let f = CGEventFlags(rawValue: flags)
        func need(_ bit: Int32, _ mask: CGEventFlags) -> Bool {
            (status & bit != 0) == f.contains(mask)   // required == present
        }
        return need(0x100, .maskControl)
            && need(0x200, .maskAlternate)
            && need(0x400, .maskCommand)
            && need(0x800, .maskShift)
    }
}
