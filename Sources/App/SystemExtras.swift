/// Pure model for the Hệ thống tab's deferred (unbacked) toggle rows (screen ⑥).
/// Both are UI placeholders — no engine backing yet — so `enabled` is false.
enum SystemExtras {
    struct Row: Equatable {
        let title: String
        let subtitle: String?
        let enabled: Bool
    }

    /// The two disabled toggle placeholders, in mockup order.
    static var placeholderRows: [Row] {
        [
            Row(title: "Sửa lỗi autocorrect trên trình duyệt", subtitle: nil, enabled: false),
            Row(title: "Ghi nhớ bảng mã theo ứng dụng",
                subtitle: "Hữu ích với Photoshop, CAD… dùng VNI, TCVN3", enabled: false),
        ]
    }
}
