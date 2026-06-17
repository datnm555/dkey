import AppKit
import SwiftUI

@main
struct DkeyApp: App {
    @NSApplicationDelegateAdaptor(DkeyAppDelegate.self) private var appDelegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(state)
        } label: {
            MenuBarLabel()
                .environmentObject(state)
        }

        Window("dkey — Bộ gõ Tiếng Việt", id: "settings") {
            SettingsRootView()
                .environmentObject(state)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 520)
    }
}

/// Icon nằm cố định trên menu bar; cũng là nơi nhận yêu cầu mở Settings.
struct MenuBarLabel: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(nsImage: StatusIcon.image(vietnamese: state.isVietnamese, gray: state.grayIcon))
            .onReceive(NotificationCenter.default.publisher(for: .dkOpenSettingsWindow)) { _ in
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}

struct MenuContent: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Tiếng Việt  \(AppState.hotkeyDescription(state.switchKeyStatus))",
               isOn: $state.isVietnamese)

        Divider()

        Button("Cài đặt…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Divider()

        Button("Thoát dkey") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

final class DkeyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Phase 0: chưa khởi động engine/event-tap. Chỉ mở Settings lần đầu
        // để xác nhận app chạy.
        NotificationCenter.default.post(name: .dkOpenSettingsWindow, object: nil)
    }
}

extension Notification.Name {
    static let dkOpenSettingsWindow = Notification.Name("dkOpenSettingsWindow")
}
