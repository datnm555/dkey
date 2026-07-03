import Foundation

/// Bit-mask layout of one TypingWord cell (UInt32), ported from OpenKey DataType.h.
/// bits 0-15: key code; 16: caps; 17: tone ^ (â/ê/ô); 18: tone w (ơ/ư/ă);
/// 19-23: marks 1-5 (sắc/huyền/hỏi/ngã/nặng); 24: standalone (w/[/]); 25: char-code.
enum EngineMask {
    static let caps: UInt32       = 0x10000
    static let tone: UInt32       = 0x20000
    static let toneW: UInt32      = 0x40000
    static let mark1: UInt32      = 0x80000
    static let mark2: UInt32      = 0x100000
    static let mark3: UInt32      = 0x200000
    static let mark4: UInt32      = 0x400000
    static let mark5: UInt32      = 0x800000
    static let mark: UInt32       = 0xF80000   // any mark
    static let char: UInt32       = 0xFFFF     // low 16 bits = key/char code
    static let standalone: UInt32 = 0x1000000
    static let charCode: UInt32   = 0x2000000
    static let pureCharacter: UInt32 = 0x80000000
    static let endConsonant: UInt32  = 0x4000
    static let consonantAllow: UInt32 = 0x8000
}

extension UInt32 {
    var cellKeyCode: UInt16 { UInt16(self & EngineMask.char) }
    var cellHasMark: Bool { (self & EngineMask.mark) != 0 }
    var cellHasCaps: Bool { (self & EngineMask.caps) != 0 }
}
