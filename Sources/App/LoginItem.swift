import ServiceManagement

/// Launch-at-login via the macOS SMAppService (login items). Errors are logged, never fatal.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else  { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("dkey: SMAppService \(on ? "register" : "unregister") failed: \(error.localizedDescription)")
        }
    }
}
