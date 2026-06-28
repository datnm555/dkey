import AppKit

/// Vẽ icon menu bar: chữ "V" (tiếng Việt) hoặc "E" (English) trong khung bo góc.
enum StatusIcon {
    static func image(vietnamese: Bool, gray: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let letter = vietnamese ? "V" : "E"
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
        let color: NSColor = gray ? .labelColor : .controlAccentColor
        color.setStroke()
        path.lineWidth = 1.2
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: color,
        ]
        let str = NSAttributedString(string: letter, attributes: attrs)
        let strSize = str.size()
        let point = NSPoint(x: (size.width - strSize.width) / 2,
                            y: (size.height - strSize.height) / 2)
        str.draw(at: point)

        image.isTemplate = gray
        return image
    }
}
