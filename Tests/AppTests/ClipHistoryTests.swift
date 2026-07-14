import XCTest
@testable import dkey

/// Thứ tự ghim/dedupe/cắt của lịch sử clipboard — value-type thuần, không I/O.
final class ClipHistoryTests: XCTestCase {
    private func texts(_ h: ClipHistory) -> [String] { h.items.map(\.text) }
    private func id(_ h: ClipHistory, text: String) -> UUID {
        h.items.first(where: { $0.text == text })!.id
    }

    func testInsertPutsNewestFirst() {
        var h = ClipHistory()
        h.insertText("a"); h.insertText("b"); h.insertText("c")
        XCTAssertEqual(texts(h), ["c", "b", "a"])
    }

    func testInsertDeduplicatesUnpinnedText() {
        var h = ClipHistory()
        h.insertText("a"); h.insertText("b"); h.insertText("c")
        h.insertText("a")                     // "a" cũ bị gỡ, "a" mới lên đầu
        XCTAssertEqual(texts(h), ["a", "c", "b"])
    }

    func testInsertBelowPinnedBlock() {
        var h = ClipHistory()
        h.insertText("a"); h.insertText("b")  // [b, a]
        h.togglePin(id: id(h, text: "b"))     // [b(pinned), a]
        h.insertText("c")                     // chèn dưới khối ghim
        XCTAssertEqual(texts(h), ["b", "c", "a"])
        XCTAssertTrue(h.items.first!.pinned)
    }

    func testInsertIdenticalToPinnedIsIgnored() {
        var h = ClipHistory()
        h.insertText("a")
        h.togglePin(id: id(h, text: "a"))     // "a" ghim
        h.insertText("a")                     // trùng nội dung đã ghim → bỏ qua
        XCTAssertEqual(texts(h), ["a"])
        XCTAssertEqual(h.items.count, 1)
    }

    func testTogglePinMovesIntoPinnedBlockAndBack() {
        var h = ClipHistory()
        h.insertText("a"); h.insertText("b"); h.insertText("c")  // [c,b,a]
        h.togglePin(id: id(h, text: "a"))     // [a(pinned), c, b]
        XCTAssertEqual(texts(h), ["a", "c", "b"])
        h.togglePin(id: id(h, text: "a"))     // bỏ ghim → về đầu khối chưa ghim
        XCTAssertEqual(texts(h), ["a", "c", "b"])
        XCTAssertFalse(h.items.first!.pinned)
    }

    func testPromoteMovesUnpinnedToTop() {
        var h = ClipHistory()
        h.insertText("a"); h.insertText("b"); h.insertText("c")  // [c,b,a]
        h.promote(id: id(h, text: "a"))
        XCTAssertEqual(texts(h), ["a", "c", "b"])
    }

    func testTrimDropsOldestUnpinnedKeepingPinned() {
        var h = ClipHistory()
        h.insertText("a"); h.insertText("b"); h.insertText("c")  // [c,b,a]
        h.togglePin(id: id(h, text: "c"))     // [c(pinned), b, a]
        let dropped = h.applyTrim(maxItems: 2) // pinned=1 → allowedUnpinned=1 → drop oldest unpinned "a"
        XCTAssertEqual(texts(h), ["c", "b"])
        XCTAssertEqual(dropped.map(\.text), ["a"])
    }

    func testClearKeepsPinned() {
        var h = ClipHistory()
        h.insertText("a"); h.insertText("b")
        h.togglePin(id: id(h, text: "a"))
        h.clearKeepingPinned()
        XCTAssertEqual(texts(h), ["a"])
    }

    func testRemoveById() {
        var h = ClipHistory()
        h.insertText("a"); h.insertText("b")
        h.remove(id: id(h, text: "a"))
        XCTAssertEqual(texts(h), ["b"])
    }

    func testFirstUnpinnedIndex() {
        var h = ClipHistory()
        h.insertText("a"); h.insertText("b"); h.insertText("c")
        h.togglePin(id: id(h, text: "c"))     // [c(pinned), b, a]
        XCTAssertEqual(ClipHistory.firstUnpinnedIndex(in: h.items), 1)
    }
}
