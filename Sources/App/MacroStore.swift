import Foundation

/// Persists macros to a JSON file; imports JSON or TSV (`key<TAB>content` per line).
struct MacroStore {
    private let fileURL: URL

    init(directory: URL = MacroStore.defaultDirectory) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("macros.json")
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dkey", isDirectory: true)
    }

    func load() -> [Macro] { decode(fileURL) }

    func save(_ macros: [Macro]) {
        guard let data = try? JSONEncoder().encode(macros) else { return }
        try? data.write(to: fileURL)
    }

    func export(_ macros: [Macro], to url: URL) throws {
        try JSONEncoder().encode(macros).write(to: url)
    }

    /// Import JSON (array of Macro) or, failing that, TSV lines `key<TAB>content`.
    func importMacros(from url: URL) -> [Macro] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        if let m = try? JSONDecoder().decode([Macro].self, from: data) { return m }
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2, !parts[0].isEmpty else { return nil }
            return Macro(key: parts[0], content: parts[1])
        }
    }

    private func decode(_ url: URL) -> [Macro] {
        guard let data = try? Data(contentsOf: url),
              let m = try? JSONDecoder().decode([Macro].self, from: data) else { return [] }
        return m
    }
}
