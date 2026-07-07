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
        didSet { if !_isReflecting { controller.setVietnamese(isVietnamese); persist() } }
    }
    @Published var inputMethod: InputMethod = .telex {
        didSet { if !_isReflecting { controller.engine.inputMethod = inputMethod; controller.engine.newSession(); persist() } }
    }
    @Published var useModernOrthography: Bool = true {
        didSet { if !_isReflecting { controller.engine.useModernOrthography = useModernOrthography; controller.engine.newSession(); persist() } }
    }
    @Published var grayIcon: Bool = false
    @Published var selectedPage: SettingsPage = .typing
    @Published var switchKeyStatus: Int32 = AppState.defaultSwitchKeyStatus {
        didSet { if !_isReflecting { controller.switchKeyStatus = switchKeyStatus; persist() } }
    }

    private let store = SettingsStore()
    private let macroStore = MacroStore()
    private var _isReflecting = false

    @Published var macros: [Macro] = [] {
        didSet { if !_isReflecting { controller.macro.setMacros(macros); macroStore.save(macros) } }
    }
    @Published var useMacro: Bool = false {
        didSet { if !_isReflecting { applyMacroFlags(); persist() } }
    }
    @Published var useMacroInEnglishMode: Bool = false {
        didSet { if !_isReflecting { applyMacroFlags(); persist() } }
    }
    @Published var autoCapsMacro: Bool = false {
        didSet { if !_isReflecting { applyMacroFlags(); persist() } }
    }

    private init() {
        let s = store.load()
        _isReflecting = true
        isVietnamese = s.isVietnamese
        inputMethod = s.inputMethod
        useModernOrthography = s.useModernOrthography
        switchKeyStatus = s.switchKeyStatus
        useMacro = s.useMacro
        useMacroInEnglishMode = s.useMacroInEnglishMode
        autoCapsMacro = s.autoCapsMacro
        grayIcon = s.grayIcon
        macros = macroStore.load()
        _isReflecting = false
        controller.apply(inputMethod: s.inputMethod, modernOrthography: s.useModernOrthography, switchKeyStatus: s.switchKeyStatus)
        controller.setVietnamese(s.isVietnamese)
        applyMacroFlags()
        controller.macro.setMacros(macros)
    }

    private func applyMacroFlags() {
        controller.macro.isEnabled = useMacro
        controller.macro.autoCaps = autoCapsMacro
        controller.useMacroInEnglishMode = useMacroInEnglishMode
    }

    private func persist() {
        store.save(DkeySettings(inputMethod: inputMethod,
                                useModernOrthography: useModernOrthography,
                                switchKeyStatus: switchKeyStatus,
                                isVietnamese: isVietnamese,
                                useMacro: useMacro,
                                useMacroInEnglishMode: useMacroInEnglishMode,
                                autoCapsMacro: autoCapsMacro,
                                grayIcon: grayIcon, showIconOnDock: false, showUIOnStartup: false,
                                runOnStartup: false, useSmartSwitchKey: false))
    }

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
