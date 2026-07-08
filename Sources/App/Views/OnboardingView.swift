import SwiftUI
import AppKit

struct OnboardingView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isTrusted = PermissionMonitor.isTrusted

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 72, height: 72)
            Text("Chào mừng đến với DKey").font(.title).bold().foregroundStyle(Color.dkText)
            Text("Bộ gõ tiếng Việt cho macOS").foregroundStyle(Color.dkSecondary)

            VStack(alignment: .leading, spacing: 10) {
                if isTrusted {
                    Label("Đã cấp quyền Trợ năng", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.dkSuccess)
                } else {
                    Text("Cấp quyền Trợ năng").font(.headline)
                    Text("System Settings → Privacy & Security → Accessibility")
                        .font(.callout).foregroundStyle(Color.dkSecondary)
                    Button("Mở System Settings") { NSWorkspace.shared.open(Onboarding.accessibilitySettingsURL) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.dkPanel, in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Button("Để sau") { finish() }
                Spacer()
                Button(isTrusted ? "Bắt đầu" : "Để sau và bắt đầu") { finish() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 420)
        .background(Color.dkWindowBg)
        .onAppear {
            // Live status: flip to trusted when the user grants it in System Settings.
            PermissionMonitor.waitUntilTrusted { isTrusted = true }
        }
    }

    private func finish() {
        state.completeOnboarding()
        dismiss()
    }
}
