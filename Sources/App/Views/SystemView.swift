import SwiftUI

struct SystemView: View {
    @EnvironmentObject private var state: AppState
    @State private var confirmingReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: "Hệ thống") {
                    VStack(spacing: 10) {
                        ToggleRow(title: "Khởi động cùng macOS", isOn: $state.runOnStartup)
                        ToggleRow(title: "Hiện cửa sổ Cài đặt khi khởi động", isOn: $state.showUIOnStartup)
                        ToggleRow(title: "Biểu tượng đơn sắc trên menu bar", isOn: $state.grayIcon)
                        ToggleRow(title: "Hiện biểu tượng ở Dock", isOn: $state.showIconOnDock)
                        ToggleRow(title: SystemExtras.placeholderRows[0].title,
                                  subtitle: SystemExtras.placeholderRows[0].subtitle,
                                  isOn: .constant(false),
                                  enabled: SystemExtras.placeholderRows[0].enabled)
                    }
                }

                SectionCard(title: "Cài đặt theo ứng dụng") {
                    VStack(alignment: .leading, spacing: 10) {
                        ToggleRow(title: "Chuyển chế độ thông minh",
                                  subtitle: "Tự nhớ chế độ Việt/Anh của từng ứng dụng khi chuyển qua lại",
                                  isOn: $state.useSmartSwitchKey)
                        ToggleRow(title: SystemExtras.placeholderRows[1].title,
                                  subtitle: SystemExtras.placeholderRows[1].subtitle,
                                  isOn: .constant(false),
                                  enabled: SystemExtras.placeholderRows[1].enabled)
                        HStack(spacing: 8) {
                            Image(systemName: "macwindow.on.rectangle")
                                .foregroundStyle(Color.dkSecondary)
                                .accessibilityHidden(true)
                            Text("Cấu hình từng ứng dụng — sắp có")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dkSecondary)
                            Spacer()
                        }
                        .opacity(0.5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }

                Button("Khôi phục cài đặt mặc định", role: .destructive) {
                    confirmingReset = true
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: 560)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dkWindowBg)
        .confirmationDialog("Khôi phục toàn bộ cài đặt về mặc định?",
                            isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Khôi phục", role: .destructive) { state.resetToDefaults() }
            Button("Huỷ", role: .cancel) {}
        }
    }
}
