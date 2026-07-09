import SwiftUI
import AppKit

struct AboutView: View {
    private let dkeyURL = URL(string: "https://github.com/datnm555/dkey")!
    private let openKeyURL = URL(string: "https://github.com/tuyenvm/OpenKey")!
    private let releasesURL = URL(string: "https://github.com/datnm555/dkey/releases")!

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: "Giới thiệu") {
                    VStack(spacing: 10) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable().frame(width: 64, height: 64)
                        Text("dkey").font(.title).bold().foregroundStyle(Color.dkText)
                        Text("Bộ gõ Tiếng Việt cho macOS")
                            .foregroundStyle(Color.dkSecondary)
                        Text("Phiên bản \(AppInfo.displayVersion)")
                            .font(.callout).foregroundStyle(Color.dkSecondary)

                        Divider().frame(maxWidth: 260).padding(.vertical, 4)

                        Text("Giấy phép GPL v3 · Engine port từ OpenKey (Tuyen Mai)")
                            .font(.footnote).foregroundStyle(Color.dkSecondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button("Mã nguồn dkey") { NSWorkspace.shared.open(dkeyURL) }
                            Button("OpenKey") { NSWorkspace.shared.open(openKeyURL) }
                            Button("Kiểm tra cập nhật") { NSWorkspace.shared.open(releasesURL) }
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dkWindowBg)
    }
}
