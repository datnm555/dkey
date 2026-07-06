import Foundation

struct DkeySettings: Equatable {
    var inputMethod: InputMethod
    var useModernOrthography: Bool
    var switchKeyStatus: Int32
    var isVietnamese: Bool
    var useMacro: Bool
    var useMacroInEnglishMode: Bool
    var autoCapsMacro: Bool

    static let defaults = DkeySettings(
        inputMethod: .telex,
        useModernOrthography: true,
        switchKeyStatus: 0x7A000206,
        isVietnamese: true,
        useMacro: false,
        useMacroInEnglishMode: false,
        autoCapsMacro: false
    )
}

// MARK: - Codable with backwards-compatible decoding for new fields
extension DkeySettings: Codable {
    enum CodingKeys: String, CodingKey {
        case inputMethod, useModernOrthography, switchKeyStatus, isVietnamese
        case useMacro, useMacroInEnglishMode, autoCapsMacro
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
    }
}
