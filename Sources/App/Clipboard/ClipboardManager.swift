import AppKit
import Carbon.HIToolbox
import Combine

/// Lịch sử clipboard: theo dõi NSPasteboard tìm text/ảnh mới, giữ ring buffer có giới hạn,
/// lưu lại, và cho mở picker bằng hotkey toàn cục. Thứ tự do `ClipHistory` (thuần) quyết định.
/// Hoàn toàn tách khỏi engine. (Cửa sổ picker + dán được thêm ở PR8b qua `onTogglePicker`.)
@MainActor
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    /// ⌃V mặc định: keycode V (0x09), bit Control (0x100), ký tự hiển thị 'v' (0x76).
    static let defaultHotKey: Int32 = 0x7600_0109
    private nonisolated static let maxImageBytes = 12 * 1024 * 1024

    private let defaults = UserDefaults.standard
    private let itemsKey = "clipboardItems"

    @Published var enabled: Bool {
        didSet {
            guard oldValue != enabled else { return }
            defaults.set(enabled, forKey: "clipboardHistoryEnabled")
            enabled ? start() : stop()
        }
    }
    @Published var hotKey: Int32 {
        didSet {
            guard oldValue != hotKey else { return }
            defaults.set(Int(hotKey), forKey: "clipboardHotKey")
            updateHotKeyRegistration()
        }
    }
    @Published var maxItems: Int {
        didSet {
            guard oldValue != maxItems else { return }
            defaults.set(maxItems, forKey: "clipboardMaxItems")
            trim()
        }
    }
    @Published var pinOnTop: Bool {
        didSet {
            guard oldValue != pinOnTop else { return }
            defaults.set(pinOnTop, forKey: "clipboardPickerPinOnTop")
        }
    }
    @Published var autoHide: Bool {
        didSet {
            guard oldValue != autoHide else { return }
            defaults.set(autoHide, forKey: "clipboardPickerAutoHide")
        }
    }

    @Published private(set) var items: [ClipItem] = []

    /// Được PR8b gán để mở/đóng cửa sổ picker khi bấm hotkey / menu.
    var onTogglePicker: (() -> Void)?

    private var history = ClipHistory()
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let hotKeyMonitor = GlobalHotKey()
    private let imageDir: URL

    private init() {
        defaults.register(defaults: [
            "clipboardHistoryEnabled": true,
            "clipboardMaxItems": 30,
            "clipboardPickerPinOnTop": true,
            "clipboardPickerAutoHide": true,
        ])
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        imageDir = appSupport.appendingPathComponent("dkey/clipboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)

        enabled = defaults.bool(forKey: "clipboardHistoryEnabled")
        maxItems = max(10, min(100, defaults.integer(forKey: "clipboardMaxItems")))
        pinOnTop = defaults.bool(forKey: "clipboardPickerPinOnTop")
        autoHide = defaults.bool(forKey: "clipboardPickerAutoHide")
        let savedHotKey = Int32(truncatingIfNeeded: defaults.integer(forKey: "clipboardHotKey"))
        hotKey = savedHotKey == 0 ? ClipboardManager.defaultHotKey : savedHotKey
        lastChangeCount = pasteboard.changeCount
        loadItems()

        hotKeyMonitor.onPressed = { [weak self] in
            Task { @MainActor in self?.togglePicker() }
        }
    }

    func imageURL(for item: ClipItem) -> URL? {
        guard let file = item.imageFile else { return nil }
        return imageDir.appendingPathComponent(file)
    }

    // MARK: Lifecycle

    func startIfEnabled() { if enabled { start() } }

    private func start() {
        updateHotKeyRegistration()
        lastChangeCount = pasteboard.changeCount
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        hotKeyMonitor.unregister()
    }

    private func updateHotKeyRegistration() {
        guard enabled else { hotKeyMonitor.unregister(); return }
        hotKeyMonitor.register(status: hotKey)
    }

    func suspendHotKey() { hotKeyMonitor.unregister() }
    func resumeHotKey() { updateHotKeyRegistration() }

    // MARK: Polling

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        if isSensitive() { return }

        let source = NSWorkspace.shared.frontmostApplication?.localizedName

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let html = pasteboard.string(forType: .html)
            addText(text, htmlText: html, source: source)
            return
        }

        guard let types = pasteboard.types else { return }
        if types.contains(.png), let png = pasteboard.data(forType: .png),
           png.count <= ClipboardManager.maxImageBytes {
            addImage(png, source: source)
        } else if types.contains(.tiff), let tiff = pasteboard.data(forType: .tiff),
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]),
                  png.count <= ClipboardManager.maxImageBytes {
            addImage(png, source: source)
        }
    }

    /// Bỏ qua trình quản lý mật khẩu và app đánh dấu nội dung nhạy cảm/tạm thời.
    private func isSensitive() -> Bool {
        guard let types = pasteboard.types else { return false }
        let names = types.map { $0.rawValue }
        let blocked = ["org.nspasteboard.ConcealedType",
                       "org.nspasteboard.TransientType",
                       "com.agilebits.onepassword",
                       "com.apple.is-sensitive"]
        return names.contains { blocked.contains($0) }
    }

    // MARK: Mutations

    private func addText(_ text: String, htmlText: String?, source: String?) {
        history.insertText(text, htmlText: htmlText, source: source)
        commitAfterInsert()
    }

    private func addImage(_ png: Data, source: String?) {
        let filename = "\(UUID().uuidString).png"
        do { try png.write(to: imageDir.appendingPathComponent(filename)) } catch { return }
        let label: String
        if let rep = NSBitmapImageRep(data: png) {
            label = "Hình ảnh \(rep.pixelsWide)×\(rep.pixelsHigh)"
        } else {
            label = "Hình ảnh"
        }
        history.insertImage(file: filename, label: label, source: source)
        commitAfterInsert()
    }

    private func commitAfterInsert() {
        let dropped = history.applyTrim(maxItems: maxItems)
        deleteImageFiles(of: dropped)
        items = history.items
        persistItems()
    }

    func togglePin(_ item: ClipItem) {
        history.togglePin(id: item.id)
        items = history.items
        persistItems()
    }

    func remove(_ item: ClipItem) {
        deleteImageFiles(of: [item])
        history.remove(id: item.id)
        items = history.items
        persistItems()
    }

    func clear() {
        deleteImageFiles(of: items.filter { !$0.pinned })
        history.clearKeepingPinned()
        items = history.items
        persistItems()
    }

    /// Đưa mục vừa dán lên đầu (mục ghim không xê dịch).
    func promote(_ item: ClipItem) {
        history.promote(id: item.id)
        items = history.items
        persistItems()
    }

    private func trim() {
        let dropped = history.applyTrim(maxItems: maxItems)
        deleteImageFiles(of: dropped)
        items = history.items
        persistItems()
    }

    private func deleteImageFiles<S: Sequence>(of seq: S) where S.Element == ClipItem {
        for item in seq {
            if let url = imageURL(for: item) { try? FileManager.default.removeItem(at: url) }
        }
    }

    // MARK: Picker (nối ở PR8b)

    func togglePicker() {
        guard enabled else { return }
        onTogglePicker?()
    }

    // MARK: Persistence

    private func loadItems() {
        guard let data = defaults.data(forKey: itemsKey),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) else { return }
        // giữ lại các mục ảnh còn file
        let valid = decoded.filter { item in
            guard item.isImage else { return true }
            guard let url = imageURL(for: item) else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }
        // chuẩn hoá thứ tự (khối ghim trước) và áp cap, không bao giờ bỏ mục ghim
        let pinned = valid.filter { $0.pinned }
        let unpinned = valid.filter { !$0.pinned }
        let allowedUnpinned = max(0, maxItems - pinned.count)
        history = ClipHistory(pinned + Array(unpinned.prefix(allowedUnpinned)))
        items = history.items
    }

    private func persistItems() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: itemsKey)
        }
    }
}
