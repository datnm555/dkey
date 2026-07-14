import SwiftUI

struct SystemView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var updater = UpdateChecker.shared
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

                SectionCard(title: "Cập nhật") {
                    VStack(alignment: .leading, spacing: 10) {
                        ToggleRow(title: "Tự động kiểm tra cập nhật khi khởi động",
                                  isOn: Binding(get: { updater.autoCheckEnabled },
                                                set: { updater.autoCheckEnabled = $0 }))
                        HStack(spacing: 8) {
                            Image(systemName: updateIcon)
                                .foregroundStyle(updateIconColor)
                                .accessibilityHidden(true)
                            Text(updateStatusText)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dkSecondary)
                                .lineLimit(2)
                            Spacer()
                            if case .checking = updater.status {
                                ProgressView().controlSize(.small)
                            } else {
                                Button("Kiểm tra ngay") {
                                    Task { await updater.check(manual: true) }
                                }
                            }
                        }
                        if case .available(let info) = updater.status {
                            HStack {
                                Text("Phiên bản \(info.version) đã sẵn sàng.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.dkText)
                                Spacer()
                                Button("Xem bản mới") { updater.openReleasePage(info) }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
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

                SectionCard(title: "Tương thích nâng cao") {
                    VStack(spacing: 10) {
                        ToggleRow(title: "Gửi phím từng bước (chậm nhưng tương thích cao) — sắp có",
                                  isOn: .constant(false), enabled: false)
                        ToggleRow(title: "Tương thích bố cục bàn phím khác QWERTY — sắp có",
                                  isOn: .constant(false), enabled: false)
                    }
                    .accessibilityHidden(true)
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

    private var updateStatusText: String {
        switch updater.status {
        case .idle:              return "Phiên bản hiện tại \(updater.currentVersion)."
        case .checking:          return "Đang kiểm tra cập nhật…"
        case .upToDate:          return "Bạn đang dùng bản mới nhất (\(updater.currentVersion))."
        case .available(let i):  return "Đã có bản \(i.version)."
        case .failed(let msg):   return msg
        }
    }

    private var updateIcon: String {
        switch updater.status {
        case .available: return "arrow.down.circle.fill"
        case .failed:    return "exclamationmark.triangle.fill"
        case .upToDate:  return "checkmark.circle.fill"
        default:         return "arrow.triangle.2.circlepath"
        }
    }

    private var updateIconColor: Color {
        switch updater.status {
        case .available: return Color.dkAccent
        case .failed:    return .orange
        case .upToDate:  return Color.dkSuccess
        default:         return Color.dkSecondary
        }
    }
}
