import Foundation

/// Pure onboarding decisions + the Accessibility deep link.
enum Onboarding {
    /// Auto-open onboarding at launch only until the user has finished it once.
    static func shouldAutoOpen(completed: Bool) -> Bool { !completed }

    /// Deep link to System Settings ▸ Privacy & Security ▸ Accessibility.
    static let accessibilitySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
}
