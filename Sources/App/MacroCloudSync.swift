import Foundation

/// Mã hoá danh sách Gõ tắt cho file đồng bộ (thuần — test được).
enum MacroSyncCodec {
    static func encode(_ macros: [Macro]) -> Data {
        (try? JSONEncoder().encode(macros)) ?? Data()
    }
    static func decode(_ data: Data) -> [Macro] {
        (try? JSONDecoder().decode([Macro].self, from: data)) ?? []
    }
}

/// Gộp danh sách local & remote (thuần — test được): union theo key, remote thắng khi
/// trùng key, giữ các key chỉ có ở local.
enum MacroMerge {
    static func merged(local: [Macro], remote: [Macro]) -> [Macro] {
        var result = local
        for r in remote {
            if let i = result.firstIndex(where: { $0.key == r.key }) { result[i] = r }
            else { result.append(r) }
        }
        return result
    }
}

/// Đồng bộ danh sách Gõ tắt qua iCloud Drive. Ký ad-hoc không có Team thì container iCloud
/// = nil → hiện "iCloud không khả dụng" (không crash). Có Team + entitlement iCloud thì chạy.
@MainActor
final class MacroCloudSync: ObservableObject {
    static let shared = MacroCloudSync()

    @Published private(set) var isAvailable = false
    @Published private(set) var statusText = "Chưa bật đồng bộ."

    private let defaults = UserDefaults.standard
    private let enabledKey = "macroCloudSyncEnabled"
    private let fileName = "dkeyMacroData.json"
    private var timer: Timer?
    private var documentsURL: URL?

    /// App cung cấp danh sách macro hiện tại và nhận danh sách sau khi gộp.
    var localMacrosProvider: (() -> [Macro])?
    var applyMacros: (([Macro]) -> Void)?

    var enabled: Bool { defaults.bool(forKey: enabledKey) }

    private init() {}

    func start() {
        refreshAvailability()
        if enabled { beginPolling() }
    }

    func setEnabled(_ on: Bool) {
        defaults.set(on, forKey: enabledKey)
        refreshAvailability()
        if on {
            beginPolling()
            syncNow()
        } else {
            stopPolling()
            statusText = "Đã tắt đồng bộ."
        }
        objectWillChange.send()
    }

    /// Đồng bộ ngay: đọc remote → gộp với local → ghi lại.
    func syncNow() {
        guard enabled, isAvailable, let dir = documentsURL else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(fileName)
        let remote = readRemote(fileURL)
        let local = localMacrosProvider?() ?? []
        let merged = MacroMerge.merged(local: local, remote: remote)
        if merged != local { applyMacros?(merged) }
        writeRemote(merged, to: fileURL)
        statusText = "Đã đồng bộ qua iCloud Drive."
    }

    /// Gọi sau khi người dùng sửa danh sách để đẩy thay đổi lên iCloud.
    func localMacrosDidChange() {
        guard enabled, isAvailable else { return }
        syncNow()
    }

    // MARK: Internals

    private func refreshAvailability() {
        // Cần iCloud entitlement + Team + đăng nhập iCloud; ad-hoc → nil.
        documentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
        isAvailable = documentsURL != nil
        if !isAvailable {
            statusText = "iCloud không khả dụng (cần đăng nhập iCloud và bản ký có Team)."
        } else if enabled {
            statusText = "Đã bật đồng bộ qua iCloud Drive."
        }
    }

    private func beginPolling() {
        stopPolling()
        guard isAvailable else { return }
        let t = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.syncNow() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopPolling() { timer?.invalidate(); timer = nil }

    private func readRemote(_ url: URL) -> [Macro] {
        var result: [Macro] = []
        var err: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &err) { u in
            if let data = try? Data(contentsOf: u) { result = MacroSyncCodec.decode(data) }
        }
        return result
    }

    private func writeRemote(_ macros: [Macro], to url: URL) {
        var err: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &err) { u in
            try? MacroSyncCodec.encode(macros).write(to: u)
        }
    }
}
