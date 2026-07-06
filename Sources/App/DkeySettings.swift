import Foundation

struct DkeySettings: Codable, Equatable {
    var inputMethod: InputMethod
    var useModernOrthography: Bool
    var switchKeyStatus: Int32
    var isVietnamese: Bool

    static let defaults = DkeySettings(
        inputMethod: .telex,
        useModernOrthography: true,
        switchKeyStatus: 0x7A000206,
        isVietnamese: true
    )
}
