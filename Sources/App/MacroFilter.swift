/// Pure filter for the Gõ tắt (macro) tab search box.
enum MacroFilter {
    /// Case-insensitive substring match on `key` OR `content`. An empty or
    /// whitespace-only query returns all macros in their original order.
    static func filter(_ macros: [Macro], query: String) -> [Macro] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return macros }
        return macros.filter { $0.key.lowercased().contains(q) || $0.content.lowercased().contains(q) }
    }
}
