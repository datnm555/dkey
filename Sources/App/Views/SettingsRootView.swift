import SwiftUI

/// Cửa sổ Settings: sidebar có icon app + header "CÀI ĐẶT" + badge trạng thái quyền,
/// bám bố cục mkey. Tab `typing`/`about`/`convert`/`macro`/`system` đã có nội dung thật.
struct SettingsRootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                sidebarHeader

                List(selection: Binding(
                    get: { state.selectedPage },
                    set: { if let v = $0 { state.selectedPage = v } }
                )) {
                    Section("CÀI ĐẶT") {
                        ForEach(SettingsPage.allCases) { page in
                            Label(page.title, systemImage: page.systemImage)
                                .tag(page)
                        }
                    }
                }

                AccessibilityBadge(granted: state.hasAccessibility)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .navigationSplitViewColumnWidth(192)
        } detail: {
            Group {
                switch state.selectedPage {
                case .typing:   TypingSettingsView()
                case .about:    AboutView()
                case .convert:  ConvertView()
                case .macro:    MacroView()
                case .system:   SystemView()
                default:        placeholder(for: state.selectedPage)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    private var sidebarHeader: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 64, height: 64)
            Text("dkey")
                .font(.headline)
                .foregroundStyle(Color.dkText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func placeholder(for page: SettingsPage) -> some View {
        VStack(spacing: 8) {
            Image(systemName: page.systemImage).font(.largeTitle)
            Text(page.title).font(.title2)
            Text("(sẽ hoàn thiện ở phase sau)").foregroundStyle(.secondary)
        }
    }
}

/// Badge nhỏ cuối sidebar cho biết đã cấp quyền Trợ năng hay chưa.
private struct AccessibilityBadge: View {
    let granted: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? Color.dkSuccess : .orange)
            Text(granted ? "Đã sẵn sàng" : "Cần quyền Trợ năng")
                .font(.caption)
                .foregroundStyle(Color.dkSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dkPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}
