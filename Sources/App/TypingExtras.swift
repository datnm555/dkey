/// Pure model for the Kiểu gõ tab's deferred typing-extra rows (screen ③).
/// All five are UI placeholders — no engine backing yet — so `enabled` is false.
enum TypingExtras {
    struct Row: Equatable {
        let title: String
        let subtitle: String?
        let enabled: Bool
    }

    /// The five "Gõ tiếng Việt" rows, in mockup order. All disabled placeholders.
    static var placeholderRows: [Row] {
        [
            Row(title: "Kiểm tra chính tả", subtitle: nil, enabled: false),
            Row(title: "Khôi phục phím nếu từ sai", subtitle: nil, enabled: false),
            Row(title: "Viết hoa chữ cái đầu câu", subtitle: nil, enabled: false),
            Row(title: "Gõ nhanh Telex", subtitle: "cc = ch, gg = gi, kk = kh, nn = ng…", enabled: false),
            Row(title: "Cho phép f, z, w, j làm phụ âm đầu", subtitle: nil, enabled: false),
        ]
    }
}
