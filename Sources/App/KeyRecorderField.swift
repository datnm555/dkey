import SwiftUI
import AppKit

/// Click to record; the next keyDown (with ≥1 modifier) becomes the switch key.
struct KeyRecorderField: View {
    @Binding var status: Int32
    @State private var recording = false

    var body: some View {
        Button {
            recording.toggle()
        } label: {
            Text(recording ? "Bấm tổ hợp phím…" : AppState.hotkeyDescription(status))
                .frame(minWidth: 90)
        }
        .background(KeyCaptureView(recording: $recording) { keyCode, ascii, ctrl, opt, cmd, shift in
            if let s = SwitchKeyCodec.encode(keyCode: keyCode, displayASCII: ascii,
                                             control: ctrl, option: opt, command: cmd, shift: shift) {
                status = s
            }
            recording = false
        })
        if recording {
            Text("Cần ít nhất 1 phím bổ trợ (⌃⌥⌘⇧).")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    @Binding var recording: Bool
    let onCapture: (_ keyCode: UInt16, _ ascii: UInt8, _ ctrl: Bool, _ opt: Bool, _ cmd: Bool, _ shift: Bool) -> Void

    func makeNSView(context: Context) -> CaptureNSView {
        let v = CaptureNSView()
        v.onCapture = onCapture
        return v
    }
    func updateNSView(_ v: CaptureNSView, context: Context) {
        v.onCapture = onCapture
        if recording { DispatchQueue.main.async { v.window?.makeFirstResponder(v) } }
    }

    final class CaptureNSView: NSView {
        var onCapture: ((UInt16, UInt8, Bool, Bool, Bool, Bool) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with e: NSEvent) {
            let f = e.modifierFlags
            let ascii = (e.charactersIgnoringModifiers?.uppercased().unicodeScalars.first?.value)
                .flatMap { $0 < 128 ? UInt8($0) : nil } ?? 0
            onCapture?(e.keyCode,
                       ascii,
                       f.contains(.control), f.contains(.option), f.contains(.command), f.contains(.shift))
        }
    }
}
