import SwiftUI

struct SystemView: View {
    @EnvironmentObject private var state: AppState
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section("Biểu tượng") {
                Toggle("Biểu tượng đơn sắc trên menu bar", isOn: $state.grayIcon)
                Toggle("Hiện biểu tượng ở Dock", isOn: $state.showIconOnDock)
            }
            Section("Khởi động") {
                Toggle("Khởi động cùng máy", isOn: $state.runOnStartup)
                Toggle("Hiện cửa sổ Cài đặt khi khởi động", isOn: $state.showUIOnStartup)
            }
            Section("Thông minh") {
                Toggle("Tự nhớ chế độ gõ theo từng ứng dụng", isOn: $state.useSmartSwitchKey)
            }
            Section {
                Button("Khôi phục cài đặt mặc định", role: .destructive) { confirmingReset = true }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Khôi phục toàn bộ cài đặt về mặc định?",
                            isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Khôi phục", role: .destructive) { state.resetToDefaults() }
            Button("Huỷ", role: .cancel) {}
        }
    }
}
