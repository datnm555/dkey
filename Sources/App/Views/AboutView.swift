import SwiftUI
import AppKit

struct AboutView: View {
    private let dkeyURL = URL(string: "https://github.com/datnm555/dkey")!
    private let openKeyURL = URL(string: "https://github.com/tuyenvm/OpenKey")!

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 64, height: 64)
            Text("dkey").font(.title).bold()
            Text("Bộ gõ Tiếng Việt cho macOS")
                .foregroundStyle(.secondary)
            Text("Phiên bản \(AppInfo.displayVersion)")
                .font(.callout).foregroundStyle(.secondary)

            Divider().frame(maxWidth: 260).padding(.vertical, 4)

            Text("Giấy phép GPL v3 · Engine port từ OpenKey (Tuyen Mai)")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Mã nguồn dkey") { NSWorkspace.shared.open(dkeyURL) }
                Button("OpenKey") { NSWorkspace.shared.open(openKeyURL) }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: 360)
    }
}
