import AppKit
import Carbon.HIToolbox

/// Hotkey toàn cục dùng Carbon, cố ý TÁCH RIÊNG khỏi CGEventTap của engine để tính năng
/// clipboard không ảnh hưởng các hotkey gõ/chuyển/convert. Hotkey Carbon được hệ thống
/// tiêu thụ toàn cục và không cần quyền Trợ năng.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onPressed: (() -> Void)?

    /// Ánh xạ bitfield hotkey dùng chung (Engine.h) → cờ modifier của Carbon.
    static func carbonModifiers(from status: Int32) -> UInt32 {
        let v = UInt32(bitPattern: status)
        var m: UInt32 = 0
        if v & 0x100 != 0 { m |= UInt32(controlKey) }
        if v & 0x200 != 0 { m |= UInt32(optionKey) }
        if v & 0x400 != 0 { m |= UInt32(cmdKey) }
        if v & 0x800 != 0 { m |= UInt32(shiftKey) }
        return m
    }

    static func keyCode(from status: Int32) -> UInt32 {
        UInt32(UInt8(truncatingIfNeeded: status))
    }

    /// (Đăng ký lại) hotkey. Cần một phím thật (low byte != 0xFE) và ít nhất một modifier —
    /// nếu không sẽ chiếm phím gõ bình thường.
    func register(status: Int32) {
        unregister()
        let code = GlobalHotKey.keyCode(from: status)
        let mods = GlobalHotKey.carbonModifiers(from: status)
        guard code != 0xFE, mods != 0 else { return }

        let hotKeyID = EventHotKeyID(signature: OSType(0x444B4559), id: 1) // 'DKEY'
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, _, userData) -> OSStatus in
            guard let userData else { return noErr }
            let me = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            me.onPressed?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        RegisterEventHotKey(code, mods, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        if let eventHandler { RemoveEventHandler(eventHandler); self.eventHandler = nil }
    }

    deinit { unregister() }
}
