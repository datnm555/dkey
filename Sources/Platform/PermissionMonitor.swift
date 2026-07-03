import ApplicationServices
import Foundation

/// Accessibility trust: dkey needs it to run a session event tap.
enum PermissionMonitor {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Show the system prompt directing the user to Privacy ▸ Accessibility.
    static func prompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Poll until trust is granted, then call onGranted once (on the main queue).
    static func waitUntilTrusted(pollInterval: TimeInterval = 1.0, onGranted: @escaping () -> Void) {
        if isTrusted { onGranted(); return }
        Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { timer in
            if isTrusted { timer.invalidate(); onGranted() }
        }
    }
}
