import AppKit

/// Vẽ icon menu bar: chữ "V" (tiếng Việt) hoặc "E" (English) trong khung bo góc tô đặc.
/// Bám mkey StatusIcon: nền tô đặc xanh #0066AB (chữ trắng); chế độ đơn sắc → template đen.
enum StatusIcon {
    /// Ký tự hiển thị theo chế độ ngôn ngữ.
    static func letter(vietnamese: Bool) -> String {
        vietnamese ? "V" : "E"
    }

    /// Màu nền của icon: xanh thương hiệu khi bật màu, đen (template) khi đơn sắc.
    static func fillColor(gray: Bool) -> NSColor {
        gray ? .black
             : NSColor(srgbRed: 0x00 / 255, green: 0x66 / 255, blue: 0xAB / 255, alpha: 1)
    }

    static func image(vietnamese: Bool, gray: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 2, yRadius: 2)
        fillColor(gray: gray).setFill()
        path.fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let str = NSAttributedString(string: letter(vietnamese: vietnamese), attributes: attrs)
        let strSize = str.size()
        let point = NSPoint(x: (size.width - strSize.width) / 2,
                            y: (size.height - strSize.height) / 2)
        str.draw(at: point)

        image.isTemplate = gray
        return image
    }
}
