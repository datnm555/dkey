import SwiftUI

/// Cửa sổ Settings: sidebar 5 tab. Phase 0 nội dung tab còn rỗng,
/// sẽ thay bằng TypingPage/MacroPage/... ở phase sau.
struct SettingsRootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: Binding(
                get: { state.selectedPage },
                set: { if let v = $0 { state.selectedPage = v } }
            )) { page in
                Label(page.title, systemImage: page.systemImage)
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(180)
        } detail: {
            Group {
                switch state.selectedPage {
                case .typing: TypingSettingsView()
                case .about:  AboutView()
                default:      placeholder(for: state.selectedPage)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
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
