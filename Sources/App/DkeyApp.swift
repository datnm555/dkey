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
    @State private var didOpenOnStartup = false

    var body: some View {
        Image(nsImage: StatusIcon.image(vietnamese: state.isVietnamese, gray: state.grayIcon))
            .onAppear {
                guard !didOpenOnStartup else { return }
                didOpenOnStartup = true
                if state.showUIOnStartup {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
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
    private let synthesizer = KeySynthesizer()
    private var eventTap: EventTap?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState.shared

        // Dock icon per setting (menu-bar app defaults to accessory / no Dock).
        NSApp.setActivationPolicy(state.showIconOnDock ? .regular : .accessory)

        // Smart-switch: track the frontmost app.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier ?? ""
            MainActor.assumeIsolated { AppState.shared.handleAppActivated(bundleId: id) }
        }

        // Hotkey → UI: reflect language flips back into AppState (icon/menu).
        state.controller.onLanguageChanged = { [weak state] vi in
            DispatchQueue.main.async { state?.reflectLanguageFromEngine(vi) }
        }
        let tap = EventTap(controller: state.controller, synthesizer: synthesizer)
        eventTap = tap

        PermissionMonitor.prompt()
        PermissionMonitor.waitUntilTrusted { [weak state] in
            DispatchQueue.main.async {
                state?.hasAccessibility = true
                _ = tap.start()
            }
        }

        // Re-arm the tap after the machine wakes (macOS disables taps on sleep).
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.eventTap?.reEnable()
        }
    }
}
