import Foundation

/// Thứ tự & quy tắc của lịch sử clipboard — value type thuần (không I/O) để test kỹ.
/// Bất biến: khối ghim ở trên đầu, phần chưa ghim xếp theo độ mới; mục mới/được đẩy
/// lên nằm ngay dưới khối ghim.
struct ClipHistory {
    private(set) var items: [ClipItem]

    init(_ items: [ClipItem] = []) { self.items = items }

    /// Vị trí bắt đầu của khối chưa ghim.
    static func firstUnpinnedIndex(in list: [ClipItem]) -> Int {
        list.firstIndex(where: { !$0.pinned }) ?? list.count
    }

    /// Thêm text mới. Nếu đã có bản ghim cùng nội dung → bỏ qua; nếu có bản chưa ghim
    /// cùng nội dung → gỡ bản cũ rồi đưa bản mới lên đầu khối chưa ghim (dedupe).
    mutating func insertText(_ text: String, htmlText: String? = nil, source: String? = nil) {
        if items.contains(where: { $0.pinned && !$0.isImage && $0.text == text }) { return }
        var next = items.filter { $0.pinned || $0.isImage || $0.text != text }
        next.insert(ClipItem(text: text, htmlText: htmlText, source: source),
                    at: ClipHistory.firstUnpinnedIndex(in: next))
        items = next
    }

    mutating func insertImage(file: String, label: String, source: String? = nil) {
        var next = items
        next.insert(ClipItem(imageFile: file, label: label, source: source),
                    at: ClipHistory.firstUnpinnedIndex(in: next))
        items = next
    }

    /// Ghim/bỏ ghim: mục di chuyển tới ranh giới giữa khối ghim và phần còn lại.
    mutating func togglePin(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var next = items
        var moved = next.remove(at: idx)
        moved.pinned.toggle()
        next.insert(moved, at: ClipHistory.firstUnpinnedIndex(in: next))
        items = next
    }

    /// Đưa một mục chưa ghim lên đầu (sau khi người dùng dán). Mục ghim không xê dịch.
    mutating func promote(id: UUID) {
        guard let item = items.first(where: { $0.id == id }), !item.pinned else { return }
        var next = items.filter { $0.id != id }
        next.insert(item, at: ClipHistory.firstUnpinnedIndex(in: next))
        items = next
    }

    mutating func remove(id: UUID) { items.removeAll { $0.id == id } }

    /// Dọn lịch sử nhưng giữ mục ghim.
    mutating func clearKeepingPinned() { items = items.filter { $0.pinned } }

    /// Cắt còn `maxItems`; mục ghim KHÔNG bị tính vào cap — chỉ bỏ các mục chưa ghim cũ nhất.
    /// Trả về danh sách mục bị bỏ (để bên ngoài xoá file ảnh kèm theo).
    @discardableResult
    mutating func applyTrim(maxItems: Int) -> [ClipItem] {
        let pinnedCount = items.lazy.filter { $0.pinned }.count
        let allowedUnpinned = max(0, maxItems - pinnedCount)
        let unpinned = items.filter { !$0.pinned }
        guard unpinned.count > allowedUnpinned else { return [] }
        let dropped = Array(unpinned.suffix(unpinned.count - allowedUnpinned))
        let droppedIDs = Set(dropped.map(\.id))
        items.removeAll { droppedIDs.contains($0.id) }
        return dropped
    }
}
