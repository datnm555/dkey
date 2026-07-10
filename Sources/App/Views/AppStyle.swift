import SwiftUI

/// Kích thước dùng chung cho các màn Settings, khớp mkey `AppStyle`.
enum AppStyle {
    /// Bề rộng tối đa của vùng nội dung (căn giữa cửa sổ rộng).
    static let contentMaxWidth: CGFloat = 680
    /// Bo góc cho control (button/field).
    static let controlCornerRadius: CGFloat = 7
    /// Bo góc cho thẻ/panel.
    static let cardCornerRadius: CGFloat = 8
}

extension View {
    /// Giới hạn bề rộng nội dung và căn trên — dùng cho các trang Settings.
    func settingsContentFrame() -> some View {
        self
            .frame(maxWidth: AppStyle.contentMaxWidth, maxHeight: .infinity, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
