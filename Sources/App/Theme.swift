import SwiftUI

extension Color {
    /// 0xRRGGBB → Color (sRGB).
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255,
                  opacity: 1)
    }

    // Palette from DKey Mockups.standalone.html
    static let dkWindowBg  = Color(hex: 0xFAF9F5)
    static let dkPanel     = Color(hex: 0xF5F5F7)
    static let dkText      = Color(hex: 0x1D1D1F)
    static let dkSecondary = Color(hex: 0x86868B)
    static let dkAccent    = Color(hex: 0x5BA7F7)
    static let dkSuccess   = Color(hex: 0x28C840)
}
