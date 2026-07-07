import Foundation

/// Per-app Vietnamese/English memory (bundleId → isVietnamese). Pure — no NSWorkspace.
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

    private func save() {
        if let data = try? JSONEncoder().encode(map) { defaults.set(data, forKey: Self.key) }
    }
}
