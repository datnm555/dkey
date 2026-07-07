# Hệ thống (System) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A "Hệ thống" tab: menu-bar/Dock icon options, show-UI-on-startup, launch-at-login (SMAppService), per-app smart-switch (remember Vi/En per app), and reset-to-defaults.

**Architecture:** 5 Bool toggles extend `DkeySettings`; a pure `SmartSwitch` holds the per-app language map; `LoginItem` wraps `SMAppService`; `AppState` publishes/applies the toggles and orchestrates smart-switch (apply on app-activate, remember on user language change, anti-loop via a `restoringForApp` flag); `DkeyApp` supplies the AppKit glue (activation policy, startup window, NSWorkspace app-activate observer). The `TelexEngine` is untouched.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit + ServiceManagement (macOS 14), XCTest, XcodeGen.

## Global Constraints

- `TelexEngine`/engine diacritic logic NOT modified — this feature is App/Platform layer only.
- 5 new `DkeySettings` Bool fields (`grayIcon`, `showIconOnDock`, `showUIOnStartup`, `runOnStartup`, `useSmartSwitchKey`), all default `false`, decoded with `decodeIfPresent ?? false` (backward-compat with old persisted JSON) — mirror the existing macro-field pattern in `DkeySettings.init(from:)`.
- `SmartSwitch` is PURE (no `NSWorkspace`/AppKit): a `[String: Bool]` bundleId→(Vietnamese) map persisted to `UserDefaults` key `dkey.smartswitch.v1`.
- Smart-switch anti-loop: apply a remembered language on app-activate WITHOUT re-remembering it, guarded by `restoringForApp`; remember only on user-initiated language change (menu toggle or ⌥Z hotkey).
- Launch-at-login uses `SMAppService.mainApp` (macOS 13+; deployment target is 14). Failures (e.g. non-notarized dev build) are logged, never crash; the UI reflects the real `SMAppService.mainApp.status`.
- No regression: all prior tests (124 on `main`) stay green; engine parity unaffected.
- XcodeGen: `xcodegen generate` after adding any new source/test file. `dkey.xcodeproj` gitignored — never commit.
- Work on `feature/system` (already created), commit after each task.

---

## File Structure

- `Sources/Platform/SmartSwitch.swift` *(new)* — pure per-app language map.
- `Sources/App/LoginItem.swift` *(new)* — SMAppService wrapper.
- `Sources/App/DkeySettings.swift` *(modify)* — 5 new fields.
- `Sources/App/AppState.swift` *(modify)* — publish/apply toggles, smart-switch orchestration, reset.
- `Sources/App/DkeyApp.swift` *(modify)* — activation policy, startup window, app-activate observer.
- `Sources/App/Views/SystemView.swift` *(new)* — the tab.
- `Sources/App/Views/SettingsRootView.swift` *(modify)* — route `.system`.
- `Tests/SystemTests/*` *(new)*; `project.yml` *(modify)* — add `Tests/SystemTests`.

---

## Task 1: SmartSwitch (pure per-app map)

**Files:**
- Create: `Sources/Platform/SmartSwitch.swift`
- Create: `Tests/SystemTests/SmartSwitchTests.swift`
- Modify: `project.yml` (add `Tests/SystemTests`)

**Interfaces:**
- Produces: `final class SmartSwitch { init(defaults: UserDefaults = .standard); var isEnabled: Bool; func languageFor(_ bundleId: String) -> Bool?; func remember(_ bundleId: String, vietnamese: Bool); func reset() }`.

- [ ] **Step 1: Add the test dir to project.yml**

In `project.yml` under `dkeyTests: sources:`, add `- path: Tests/SystemTests`. Then `xcodegen generate`.

- [ ] **Step 2: Write the failing tests**

Create `Tests/SystemTests/SmartSwitchTests.swift`:

```swift
import XCTest
@testable import dkey

final class SmartSwitchTests: XCTestCase {
    private func fresh() -> UserDefaults { UserDefaults(suiteName: "dkey.tests.\(UUID().uuidString)")! }

    func testUnknownBundleReturnsNil() {
        XCTAssertNil(SmartSwitch(defaults: fresh()).languageFor("com.apple.Safari"))
    }

    func testRememberAndRecall() {
        let s = SmartSwitch(defaults: fresh())
        s.remember("com.apple.Safari", vietnamese: false)
        s.remember("com.apple.TextEdit", vietnamese: true)
        XCTAssertEqual(s.languageFor("com.apple.Safari"), false)
        XCTAssertEqual(s.languageFor("com.apple.TextEdit"), true)
    }

    func testEmptyBundleIgnored() {
        let s = SmartSwitch(defaults: fresh())
        s.remember("", vietnamese: true)
        XCTAssertNil(s.languageFor(""))
    }

    func testPersistRoundTrip() {
        let d = fresh()
        let a = SmartSwitch(defaults: d); a.remember("com.apple.Safari", vietnamese: false)
        XCTAssertEqual(SmartSwitch(defaults: d).languageFor("com.apple.Safari"), false)  // reload
    }

    func testReset() {
        let s = SmartSwitch(defaults: fresh())
        s.remember("com.apple.Safari", vietnamese: false); s.reset()
        XCTAssertNil(s.languageFor("com.apple.Safari"))
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `cd /Users/dat.nguyenmanh/Desktop/dat/my-git/dkey && xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: compile failure — `SmartSwitch` undefined.

- [ ] **Step 4: Implement**

Create `Sources/Platform/SmartSwitch.swift`:

```swift
import Foundation

/// Per-app Vietnamese/English memory (bundleId → isVietnamese). Pure — no NSWorkspace.
public final class SmartSwitch {
    public var isEnabled = false
    private var map: [String: Bool]
    private let defaults: UserDefaults
    private static let key = "dkey.smartswitch.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let m = try? JSONDecoder().decode([String: Bool].self, from: data) {
            map = m
        } else {
            map = [:]
        }
    }

    public func languageFor(_ bundleId: String) -> Bool? { map[bundleId] }

    public func remember(_ bundleId: String, vietnamese: Bool) {
        guard !bundleId.isEmpty else { return }
        map[bundleId] = vietnamese
        save()
    }

    public func reset() { map = [:]; save() }

    private func save() {
        if let data = try? JSONEncoder().encode(map) { defaults.set(data, forKey: Self.key) }
    }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add project.yml Sources/Platform/SmartSwitch.swift Tests/SystemTests/SmartSwitchTests.swift
git commit -m "feat(platform): SmartSwitch per-app language memory"
```

---

## Task 2: DkeySettings — 5 system fields

**Files:**
- Modify: `Sources/App/DkeySettings.swift`
- Modify: `Tests/AppTests/SettingsStoreTests.swift` (extend round-trip)

**Interfaces:**
- Produces: `DkeySettings.grayIcon/showIconOnDock/showUIOnStartup/runOnStartup/useSmartSwitchKey` (Bool).

- [ ] **Step 1: Add fields + defaults + decoder**

In `Sources/App/DkeySettings.swift`:
- Add to the struct (after `autoCapsMacro`):
```swift
    var grayIcon: Bool
    var showIconOnDock: Bool
    var showUIOnStartup: Bool
    var runOnStartup: Bool
    var useSmartSwitchKey: Bool
```
- Extend `defaults` with `grayIcon: false, showIconOnDock: false, showUIOnStartup: false, runOnStartup: false, useSmartSwitchKey: false`.
- Add the five to `CodingKeys`: `case grayIcon, showIconOnDock, showUIOnStartup, runOnStartup, useSmartSwitchKey`.
- In `init(from:)`, decode each with the backward-compat pattern:
```swift
        grayIcon          = try c.decodeIfPresent(Bool.self, forKey: .grayIcon)          ?? false
        showIconOnDock    = try c.decodeIfPresent(Bool.self, forKey: .showIconOnDock)    ?? false
        showUIOnStartup   = try c.decodeIfPresent(Bool.self, forKey: .showUIOnStartup)   ?? false
        runOnStartup      = try c.decodeIfPresent(Bool.self, forKey: .runOnStartup)      ?? false
        useSmartSwitchKey = try c.decodeIfPresent(Bool.self, forKey: .useSmartSwitchKey) ?? false
```

- [ ] **Step 2: Extend the round-trip test**

In `Tests/AppTests/SettingsStoreTests.swift`, in `testRoundTrip`, set the 5 new fields to `true` on the `s` value and assert they survive save→load. (Follow the existing lines that set the macro fields.) Example additions:
```swift
        s.grayIcon = true
        s.showIconOnDock = true
        s.showUIOnStartup = true
        s.runOnStartup = true
        s.useSmartSwitchKey = true
```

- [ ] **Step 3: Run to verify pass** (note: `AppState.persist()` won't compile yet — it constructs `DkeySettings(...)` without the new args. That's fixed in Task 4. To keep this task green, add the 5 new args to the `DkeySettings(...)` call in `AppState.persist()` now, passing the existing `grayIcon` property and `false` for the not-yet-added ones — OR do Step 3 build after Task 4. Simplest: in this task also update `AppState.persist()` and `init` minimally.)

Actually, to keep each task independently green: in THIS task, also update `AppState.persist()` to pass the 5 new fields — `grayIcon: grayIcon` (the existing `@Published var grayIcon`), and `showIconOnDock: showIconOnDock` etc. will not exist yet. To avoid a forward dependency, pass literal `false` for the four not-yet-published ones and `grayIcon` for gray:
```swift
        store.save(DkeySettings(inputMethod: inputMethod, useModernOrthography: useModernOrthography,
                                switchKeyStatus: switchKeyStatus, isVietnamese: isVietnamese,
                                useMacro: useMacro, useMacroInEnglishMode: useMacroInEnglishMode,
                                autoCapsMacro: autoCapsMacro,
                                grayIcon: grayIcon, showIconOnDock: false, showUIOnStartup: false,
                                runOnStartup: false, useSmartSwitchKey: false))
```
And in `init`, after loading `s`, add `grayIcon = s.grayIcon` under `_isReflecting` (grayIcon is already `@Published`). Task 4 replaces the `false` placeholders with real properties.

Run: `xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: `TEST SUCCEEDED` — round-trip test (with the 5 new fields) passes; grayIcon now persists.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/DkeySettings.swift Sources/App/AppState.swift Tests/AppTests/SettingsStoreTests.swift
git commit -m "feat(app): add 5 system-tab fields to DkeySettings + persist grayIcon"
```

---

## Task 3: LoginItem (SMAppService wrapper)

**Files:**
- Create: `Sources/App/LoginItem.swift`

**Interfaces:**
- Produces: `enum LoginItem { static var isEnabled: Bool { get }; static func setEnabled(_ on: Bool) }`.

- [ ] **Step 1: Implement**

Create `Sources/App/LoginItem.swift`:

```swift
import ServiceManagement

/// Launch-at-login via the macOS SMAppService (login items). Errors are logged, never fatal.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else  { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("dkey: SMAppService \(on ? "register" : "unregister") failed: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 2: Regenerate + build**

Run: `xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug build 2>&1 | tail -8`
Expected: `BUILD SUCCEEDED`. (No unit test — `SMAppService` is a system call; verified by build + Task 6 smoke.)

- [ ] **Step 3: Run the suite (regression)**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -8`
Expected: `TEST SUCCEEDED` — all prior tests green.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/LoginItem.swift
git commit -m "feat(app): LoginItem SMAppService wrapper"
```

---

## Task 4: AppState wiring — toggles, smart-switch, reset

**Files:**
- Modify: `Sources/App/AppState.swift`

**Interfaces:**
- Consumes: `SmartSwitch`, `LoginItem`, `DkeySettings`, `controller.setVietnamese`, `NSApp.setActivationPolicy`.
- Produces: `AppState.showIconOnDock/showUIOnStartup/runOnStartup/useSmartSwitchKey` (`@Published`), `AppState.smartSwitch`, `AppState.currentBundleId`, `func handleAppActivated(bundleId:)`, `func resetToDefaults()`.

- [ ] **Step 1: Add published toggles + smart-switch members**

In `AppState`, add:
```swift
    let smartSwitch = SmartSwitch()
    var currentBundleId = ""
    private var restoringForApp = false

    @Published var showIconOnDock: Bool = false {
        didSet { if !_isReflecting { NSApp.setActivationPolicy(showIconOnDock ? .regular : .accessory); persist() } }
    }
    @Published var showUIOnStartup: Bool = false {
        didSet { if !_isReflecting { persist() } }
    }
    @Published var runOnStartup: Bool = false {
        didSet { if !_isReflecting { LoginItem.setEnabled(runOnStartup); persist() } }
    }
    @Published var useSmartSwitchKey: Bool = false {
        didSet { if !_isReflecting { smartSwitch.isEnabled = useSmartSwitchKey; persist() } }
    }
```
Give `grayIcon` a persist didSet (it currently has none):
```swift
    @Published var grayIcon: Bool = false { didSet { if !_isReflecting { persist() } } }
```

- [ ] **Step 2: Wire persist(), init(), and the smart-switch handlers**

Replace the placeholder `false`s in `persist()` (from Task 2) with the real properties:
```swift
                                grayIcon: grayIcon, showIconOnDock: showIconOnDock,
                                showUIOnStartup: showUIOnStartup, runOnStartup: runOnStartup,
                                useSmartSwitchKey: useSmartSwitchKey))
```
In `init`, under `_isReflecting = true`, load the new fields:
```swift
        grayIcon = s.grayIcon
        showIconOnDock = s.showIconOnDock
        showUIOnStartup = s.showUIOnStartup
        runOnStartup = s.runOnStartup
        useSmartSwitchKey = s.useSmartSwitchKey
```
After `_isReflecting = false`, apply the smart-switch flag (do NOT re-register the login item at launch — SMAppService already reflects OS state; do NOT force activation policy here, DkeyApp sets it):
```swift
        smartSwitch.isEnabled = useSmartSwitchKey
```
Add the smart-switch handlers + reset:
```swift
    /// Frontmost app changed. If smart-switch is on and this app has a remembered language, apply it
    /// WITHOUT recording it back (restoringForApp guards remember()).
    func handleAppActivated(bundleId: String) {
        currentBundleId = bundleId
        guard useSmartSwitchKey, let vi = smartSwitch.languageFor(bundleId), vi != isVietnamese else { return }
        restoringForApp = true
        _isReflecting = true; isVietnamese = vi; _isReflecting = false   // update UI without side effects
        controller.setVietnamese(vi)                                     // flip the engine explicitly
        restoringForApp = false
    }

    /// Record the current language for the current app (called on user-initiated changes only).
    private func rememberCurrentLanguage() {
        if useSmartSwitchKey && !restoringForApp { smartSwitch.remember(currentBundleId, vietnamese: isVietnamese) }
    }

    func resetToDefaults() {
        let d = DkeySettings.defaults
        _isReflecting = true
        isVietnamese = d.isVietnamese; inputMethod = d.inputMethod
        useModernOrthography = d.useModernOrthography; switchKeyStatus = d.switchKeyStatus
        useMacro = d.useMacro; useMacroInEnglishMode = d.useMacroInEnglishMode; autoCapsMacro = d.autoCapsMacro
        grayIcon = d.grayIcon; showIconOnDock = d.showIconOnDock; showUIOnStartup = d.showUIOnStartup
        runOnStartup = d.runOnStartup; useSmartSwitchKey = d.useSmartSwitchKey
        _isReflecting = false
        controller.apply(inputMethod: d.inputMethod, modernOrthography: d.useModernOrthography, switchKeyStatus: d.switchKeyStatus)
        controller.setVietnamese(d.isVietnamese)
        applyMacroFlags(); smartSwitch.isEnabled = d.useSmartSwitchKey
        NSApp.setActivationPolicy(d.showIconOnDock ? .regular : .accessory)
        LoginItem.setEnabled(d.runOnStartup)
        persist()
    }
```
Hook `rememberCurrentLanguage()` into the two user-initiated change points:
- In `isVietnamese`'s `didSet`, inside the `if !_isReflecting { … }`, append `rememberCurrentLanguage()` (menu toggle).
- In `reflectLanguageFromEngine(_:)`, after setting `isVietnamese`, append `rememberCurrentLanguage()` (⌥Z hotkey).

- [ ] **Step 3: Build + regression**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -10`
Expected: `TEST SUCCEEDED` — all prior tests green (AppState is a `@MainActor` singleton; this wiring is verified by build + the SmartSwitch unit tests + Task 6 smoke, not new unit tests).

- [ ] **Step 4: Commit**

```bash
git add Sources/App/AppState.swift
git commit -m "feat(app): AppState system toggles + smart-switch orchestration + reset"
```

---

## Task 5: DkeyApp — activation policy, startup window, app-activate observer

**Files:**
- Modify: `Sources/App/DkeyApp.swift`

**Interfaces:**
- Consumes: `AppState.showIconOnDock/showUIOnStartup`, `AppState.handleAppActivated(bundleId:)`.

- [ ] **Step 1: Initial activation policy + app-activate observer**

In `DkeyAppDelegate.applicationDidFinishLaunching`, after `let state = AppState.shared`, add:
```swift
        // Dock icon per setting (menu-bar app defaults to accessory / no Dock).
        NSApp.setActivationPolicy(state.showIconOnDock ? .regular : .accessory)

        // Smart-switch: track the frontmost app.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier ?? ""
            DispatchQueue.main.async { AppState.shared.handleAppActivated(bundleId: id) }
        }
```

- [ ] **Step 2: Show settings on startup**

Add a startup-window opener to `MenuBarLabel` (its `onAppear` fires once at launch). Replace `MenuBarLabel` with:
```swift
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
```

- [ ] **Step 3: Build + regression**

Run: `xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -8`
Expected: `TEST SUCCEEDED` / `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/DkeyApp.swift
git commit -m "feat(app): activation policy, startup window, app-activate observer"
```

---

## Task 6: SystemView + tab wiring

**Files:**
- Create: `Sources/App/Views/SystemView.swift`
- Modify: `Sources/App/Views/SettingsRootView.swift`

**Interfaces:**
- Consumes: `AppState.grayIcon/showIconOnDock/showUIOnStartup/runOnStartup/useSmartSwitchKey`, `AppState.resetToDefaults()`.

- [ ] **Step 1: Build the view**

Create `Sources/App/Views/SystemView.swift`:

```swift
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
```

- [ ] **Step 2: Route the `.system` tab**

In `Sources/App/Views/SettingsRootView.swift`, add to the `switch`: `case .system: SystemView()` (keep `.typing`/`.about`/`.convert`/`.macro`/`default`). (If `.macro` was not yet added there in a prior feature, add it too — but it should already be present; verify.)

- [ ] **Step 3: Regenerate + build**

Run: `xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug build 2>&1 | tail -8`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Full test pass (regression gate)**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -8`
Expected: `TEST SUCCEEDED` — all system + prior tests green.

- [ ] **Step 5: Manual smoke (deferred to user)**

Open Cài đặt → Hệ thống. Toggle "Biểu tượng đơn sắc" → menu-bar icon changes. Toggle "Hiện icon ở Dock" → Dock icon appears/disappears. Toggle "Khởi động cùng máy" → appears in System Settings → Login Items (may fail on a non-notarized DerivedData build — expected; verify it doesn't crash and the toggle reflects the real status on reopen). Enable smart-switch: in TextEdit press ⌥Z to set English, switch to another app and back → TextEdit returns to English; another app keeps its own state; no flicker/loop. "Khôi phục cài đặt mặc định" → confirm → all toggles reset. Relaunch → settings persist; if "Hiện cửa sổ khi khởi động" was on, Settings opens at launch.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/Views/SystemView.swift Sources/App/Views/SettingsRootView.swift
git commit -m "feat(app): Hệ thống (system) settings tab"
```

---

## Self-Review

**1. Spec coverage:**
- Gray icon + Dock icon + show-UI-on-startup + smart-switch toggle → DkeySettings (Task 2) + AppState (Task 4) + DkeyApp (Task 5) + SystemView (Task 6). ✅
- Launch-at-login (SMAppService) → LoginItem (Task 3) + runOnStartup didSet (Task 4). ✅
- Smart-switch per-app map + anti-loop → SmartSwitch (Task 1) + handleAppActivated/rememberCurrentLanguage/restoringForApp (Task 4) + observer (Task 5). ✅
- Reset-to-defaults + confirm → resetToDefaults (Task 4) + dialog (Task 6). ✅
- Engine untouched / no regression → every task's test step. ✅
- Backward-compat decode → Task 2 decodeIfPresent. ✅

**2. Placeholder scan:** No TBD/TODO. Task 2/4 describe AppState edits against the exact existing `persist()`/`init`/`_isReflecting` structure (read from the current file) with concrete code, and the Task-2 `false` placeholders in `persist()` are explicitly replaced by real properties in Task 4 (called out in both tasks).

**3. Type consistency:** `SmartSwitch` API (Task 1) is used identically in AppState (Task 4). `LoginItem.isEnabled/setEnabled` (Task 3) matches its AppState caller (Task 4). `handleAppActivated(bundleId:)` (Task 4) matches the DkeyApp observer call (Task 5). The 5 `DkeySettings` fields (Task 2) are set in `persist()`/`init`/`resetToDefaults` (Tasks 2/4) and bound in SystemView (Task 6) — same names throughout. `AppState.resetToDefaults()` (Task 4) matches its SystemView caller (Task 6).
