import Foundation

/// Per-app Vietnamese/English memory (bundleId → isVietnamese). Pure — no NSWorkspace.
// Not thread-safe; use from the main actor only.
public final class SmartSwitch {
    public var isEnabled = false
    private var map: [String: Bool]
    private let defaults: UserDefaults
    private static let key = "dkey.smartswitch.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let m = try? JSONDecoder().decode([String: Bool].self, from: data) {
            map = m
        } else {
            map = [:]
        }
    }

    public func languageFor(_ bundleId: String) -> Bool? { map[bundleId] }

    public func remember(_ bundleId: String, vietnamese: Bool) {
        guard !bundleId.isEmpty else { return }
        map[bundleId] = vietnamese
        save()
    }

    public func reset() { map = [:]; save() }

    /// The language to switch to for `bundleId`, or nil when smart-switch is off, the app is
    /// unknown, or the remembered language already equals `current`. (Used on app activation.)
    public func applicableLanguage(for bundleId: String, current: Bool) -> Bool? {
        guard isEnabled, let vi = map[bundleId], vi != current else { return nil }
        return vi
    }

    /// Record the user's language for `bundleId` — only when smart-switch is enabled.
    public func recordIfEnabled(_ bundleId: String, vietnamese: Bool) {
        guard isEnabled else { return }
        remember(bundleId, vietnamese: vietnamese)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(map) { defaults.set(data, forKey: Self.key) }
    }
}
