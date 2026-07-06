import Foundation

/// App identity/version, read from the bundle. `versionString(from:)` is pure so it can be tested.
enum AppInfo {
    static func versionString(from info: [String: Any]?) -> String {
        guard let info,
              let short = info["CFBundleShortVersionString"] as? String,
              let build = info["CFBundleVersion"] as? String
        else { return "—" }
        return "\(short) (\(build))"
    }

    static var displayVersion: String { versionString(from: Bundle.main.infoDictionary) }
}
