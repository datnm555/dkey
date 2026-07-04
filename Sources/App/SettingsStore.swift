import Foundation

struct SettingsStore {
    static let key = "dkey.settings.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> DkeySettings {
        guard let data = defaults.data(forKey: Self.key),
              let s = try? JSONDecoder().decode(DkeySettings.self, from: data)
        else { return .defaults }
        return s
    }

    func save(_ s: DkeySettings) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
