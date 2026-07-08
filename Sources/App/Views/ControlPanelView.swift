import AppKit
import SwiftUI

/// Menu-bar popover (screen ②): master Vietnamese toggle, Kiểu gõ selector,
/// a disabled Bảng mã placeholder, and a Cài đặt/Thoát footer.
struct ControlPanelView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            masterToggle
            inputMethodRow
            codeTableRow
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
        .background(Color.dkWindowBg)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 22, height: 22)
            Text("DKey").font(.headline).foregroundStyle(Color.dkText)
            Spacer()
        }
    }

    private var masterToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tiếng Việt")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dkText)
                Text("Phím chuyển nhanh  \(AppState.hotkeyDescription(state.switchKeyStatus))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dkSecondary)
            }
            Spacer()
            Toggle("", isOn: $state.isVietnamese)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(12)
        .background(Color.dkPanel, in: RoundedRectangle(cornerRadius: 10))
    }

    private var inputMethodRow: some View {
        HStack(spacing: 10) {
            Text("Kiểu gõ")
                .font(.system(size: 12))
                .foregroundStyle(Color.dkSecondary)
                .frame(width: 56, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(Array(ControlPanel.inputMethodSegments.enumerated()), id: \.offset) { _, seg in
                    segmentButton(seg)
                }
            }
            .padding(2)
            .background(Color.dkPanel, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func segmentButton(_ seg: ControlPanel.Segment) -> some View {
        let selected = seg.method == state.inputMethod
        Text(seg.label)
            .font(.system(size: 12, weight: selected ? .semibold : .regular))
            .foregroundStyle(
                seg.enabled ? (selected ? Color.white : Color.dkText)
                            : Color.dkSecondary.opacity(0.45)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(selected ? Color.dkAccent : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
            .onTapGesture {
                guard seg.enabled, let method = seg.method else { return }
                state.inputMethod = method
            }
    }

    private var codeTableRow: some View {
        HStack(spacing: 10) {
            Text("Bảng mã")
                .font(.system(size: 12))
                .foregroundStyle(Color.dkSecondary)
                .frame(width: 56, alignment: .leading)
            HStack {
                Text("Unicode (dựng sẵn)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dkSecondary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dkSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.dkPanel, in: RoundedRectangle(cornerRadius: 8))
        }
        .opacity(0.55)
        .allowsHitTesting(false)   // disabled placeholder — no backing yet
    }

    private var footer: some View {
        HStack {
            Button("Cài đặt…") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            Spacer()
            Button("Thoát") { NSApp.terminate(nil) }
        }
        .font(.system(size: 12))
    }
}
