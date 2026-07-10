import AppKit
import Combine

/// Kiểm tra bản phát hành mới trên GitHub Releases. Tự chứa (UserDefaults riêng, độc
/// lập với engine). Vì app ký ad-hoc nên không tự cài được: chỉ báo có bản mới và mở
/// trang release để người dùng tải/cài thủ công.
struct ReleaseInfo: Equatable {
    let version: String   // ví dụ "1.4.0"
    let notes: String     // nội dung release
    let pageURL: URL      // html_url của release
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    private let defaults = UserDefaults.standard
    private let autoKey = "autoCheckUpdate"
    private let lastCheckKey = "lastUpdateCheck"
    private let releaseAPI = URL(string: "https://api.github.com/repos/datnm555/dkey/releases/latest")!
    private let minInterval: TimeInterval = 24 * 60 * 60

    var autoCheckEnabled: Bool {
        get { defaults.object(forKey: autoKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: autoKey); objectWillChange.send() }
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private init() {}

    // MARK: Public API

    /// Tự kiểm tra lúc khởi động: chỉ khi bật và đã quá 24h kể từ lần kiểm tra trước.
    func autoCheckIfDue() {
        guard autoCheckEnabled else { return }
        if let last = defaults.object(forKey: lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < minInterval {
            return
        }
        Task { await check(manual: false) }
    }

    /// Hỏi GitHub bản mới nhất. `manual` = do người dùng bấm.
    func check(manual: Bool) async {
        status = .checking
        do {
            let info = try await fetchLatest()
            defaults.set(Date(), forKey: lastCheckKey)
            if UpdateChecker.isNewer(info.version, than: currentVersion) {
                status = .available(info)
                if !manual {
                    NotificationCenter.default.post(name: .dkUpdateAvailable, object: info)
                }
            } else {
                status = .upToDate
            }
        } catch {
            status = .failed("Không kiểm tra được cập nhật. Hãy thử lại sau.")
        }
    }

    func openReleasePage(_ info: ReleaseInfo) {
        NSWorkspace.shared.open(info.pageURL)
    }

    // MARK: Networking

    private func fetchLatest() async throws -> ReleaseInfo {
        var request = URLRequest(url: releaseAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("dkey", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let notes = (json["body"] as? String) ?? ""
        let pageString = (json["html_url"] as? String) ?? "https://github.com/datnm555/dkey/releases/latest"
        let pageURL = URL(string: pageString) ?? releaseAPI
        return ReleaseInfo(version: version, notes: notes, pageURL: pageURL)
    }

    // MARK: Semver (thuần, tách static để test)

    /// True khi `remote` là phiên bản mới hơn hẳn `local`.
    /// Nếu phân tích lỗi → false để không bao giờ báo nhầm "có bản mới".
    nonisolated static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = numericComponents(remote)
        let l = numericComponents(local)
        guard !r.isEmpty, !l.isEmpty else { return false }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    /// Lấy phần "x.y.z" đầu tiên (bỏ hậu tố -beta…), tách theo dấu chấm.
    nonisolated static func numericComponents(_ version: String) -> [Int] {
        let core = version.split(whereSeparator: { !"0123456789.".contains($0) }).first.map(String.init) ?? version
        return core.split(separator: ".").map { Int($0) ?? 0 }
    }
}

extension Notification.Name {
    static let dkUpdateAvailable = Notification.Name("DKUpdateAvailable")
}
