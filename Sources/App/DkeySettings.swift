import Foundation

struct DkeySettings: Equatable {
    var inputMethod: InputMethod
    var useModernOrthography: Bool
    var switchKeyStatus: Int32
    var isVietnamese: Bool
    var useMacro: Bool
    var useMacroInEnglishMode: Bool
    var autoCapsMacro: Bool
    var grayIcon: Bool
    var showIconOnDock: Bool
    var showUIOnStartup: Bool
    var runOnStartup: Bool
    var useSmartSwitchKey: Bool
    var hasCompletedOnboarding: Bool

    static let defaults = DkeySettings(
        inputMethod: .telex,
        useModernOrthography: true,
        switchKeyStatus: 0x7A000206,
        isVietnamese: true,
        useMacro: false,
        useMacroInEnglishMode: false,
        autoCapsMacro: false,
        grayIcon: false,
        showIconOnDock: false,
        showUIOnStartup: false,
        runOnStartup: false,
        useSmartSwitchKey: false,
        hasCompletedOnboarding: false
    )
}

// MARK: - Codable with backwards-compatible decoding for new fields
extension DkeySettings: Codable {
    enum CodingKeys: String, CodingKey {
        case inputMethod, useModernOrthography, switchKeyStatus, isVietnamese
        case useMacro, useMacroInEnglishMode, autoCapsMacro
        case grayIcon, showIconOnDock, showUIOnStartup, runOnStartup, useSmartSwitchKey
        case hasCompletedOnboarding
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        inputMethod          = try c.decode(InputMethod.self, forKey: .inputMethod)
        useModernOrthography = try c.decode(Bool.self,        forKey: .useModernOrthography)
        switchKeyStatus      = try c.decode(Int32.self,       forKey: .switchKeyStatus)
        isVietnamese         = try c.decode(Bool.self,        forKey: .isVietnamese)
        // New fields: fall back to false so old persisted JSON still loads cleanly.
        useMacro             = try c.decodeIfPresent(Bool.self, forKey: .useMacro)             ?? false
        useMacroInEnglishMode = try c.decodeIfPresent(Bool.self, forKey: .useMacroInEnglishMode) ?? false
        autoCapsMacro        = try c.decodeIfPresent(Bool.self, forKey: .autoCapsMacro)        ?? false
        grayIcon          = try c.decodeIfPresent(Bool.self, forKey: .grayIcon)          ?? false
        showIconOnDock    = try c.decodeIfPresent(Bool.self, forKey: .showIconOnDock)    ?? false
        showUIOnStartup   = try c.decodeIfPresent(Bool.self, forKey: .showUIOnStartup)   ?? false
        runOnStartup      = try c.decodeIfPresent(Bool.self, forKey: .runOnStartup)      ?? false
        useSmartSwitchKey = try c.decodeIfPresent(Bool.self, forKey: .useSmartSwitchKey) ?? false
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
    }
}
