import AppKit

/// Chuyển mã văn bản trong clipboard (Unicode ⇄ TCVN3 ⇄ VNI…), theo luồng mkey:
/// sao chép văn bản → bấm nút → kết quả ghi lại vào clipboard.
/// Tách `converted` (thuần) khỏi I/O pasteboard để test.
enum ClipboardConverter {
    /// Chuyển chuỗi (nếu có). Trả nil khi không có gì để chuyển (nil hoặc rỗng).
    static func converted(_ text: String?, from: CodeTable, to: CodeTable,
                          caseMode: CaseMode, removeMark: Bool) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return ConvertTool.convert(text, from: from, to: to, caseMode: caseMode, removeMark: removeMark)
    }

    /// Đọc clipboard, chuyển mã, ghi lại. Trả true nếu có dữ liệu để chuyển.
    @discardableResult
    static func convertPasteboard(from: CodeTable, to: CodeTable, caseMode: CaseMode,
                                  removeMark: Bool, pasteboard: NSPasteboard = .general) -> Bool {
        let input = pasteboard.string(forType: .string)
        guard let out = converted(input, from: from, to: to, caseMode: caseMode, removeMark: removeMark) else {
            return false
        }
        pasteboard.clearContents()
        pasteboard.setString(out, forType: .string)
        return true
    }
}
