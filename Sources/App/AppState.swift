import SwiftUI

/// Trang trong cửa sổ Settings.
enum SettingsPage: String, CaseIterable, Identifiable {
    case typing, macro, convert, system, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .typing:  return "Kiểu gõ"
        case .macro:   return "Gõ tắt"
        case .convert: return "Chuyển mã"
        case .system:  return "Hệ thống"
        case .about:   return "Giới thiệu"
        }
    }

    var systemImage: String {
        switch self {
        case .typing:  return "keyboard"
        case .macro:   return "text.badge.plus"
        case .convert: return "arrow.left.arrow.right"
        case .system:  return "gearshape"
        case .about:   return "info.circle"
        }
    }
}

/// Nguồn sự thật cho UI. Phase 0 mới chỉ giữ vài state UI tối thiểu;
/// các cờ engine sẽ bổ sung ở phase sau. Theo pattern proven của MKey:
/// ObservableObject singleton inject qua .environmentObject.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// Bitfield hotkey chuyển ngôn ngữ (giống MKey), mặc định ⌥Z = 0x7A000206:
    /// byte cao (>>24) = 0x7A = ký tự hiển thị 'z'; bit 0x200 = phím ⌥ (Option).
    /// Phase 0 chỉ dùng để hiển thị; logic bắt phím thêm ở phase sau.
    static let defaultSwitchKeyStatus: Int32 = 0x7A000206

    /// The engine + decision core driving the event tap (Phase 2).
    let controller = InputController()
    @Published var hasAccessibility: Bool = false

    @Published var isVietnamese: Bool = true {
        didSet { if !_isReflecting { controller.setVietnamese(isVietnamese) } }
    }
    @Published var grayIcon: Bool = false
    @Published var selectedPage: SettingsPage = .typing
    @Published var switchKeyStatus: Int32 = AppState.defaultSwitchKeyStatus

    private var _isReflecting = false

    private init() {}

    /// Called from the engine/hotkey side; updates UI state without re-notifying the engine.
    func reflectLanguageFromEngine(_ vi: Bool) {
        if isVietnamese != vi { _isReflecting = true; isVietnamese = vi; _isReflecting = false }
    }

    /// Hiển thị hotkey dạng "⌥Z". Phase 0: rút gọn, đủ cho menu.
    static func hotkeyDescription(_ status: Int32) -> String {
        var parts = ""
        if status & 0x100 != 0 { parts += "⌃" }
        if status & 0x200 != 0 { parts += "⌥" }
        if status & 0x400 != 0 { parts += "⌘" }
        if status & 0x800 != 0 { parts += "⇧" }
        let display = UInt8((status >> 24) & 0xFF)
        if display != 0 {
            let scalar = Unicode.Scalar(display)
            parts += String(scalar).uppercased()
        }
        return parts
    }
}
