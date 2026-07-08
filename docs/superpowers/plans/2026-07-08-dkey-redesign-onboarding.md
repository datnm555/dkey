# Redesign Foundation + Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A shared color `Theme` (from the mockup palette) and an Onboarding window (welcome + Accessibility-grant flow with live status), auto-opened on first run.

**Architecture:** A pure `Theme` (hex→Color + named colors) and a pure `Onboarding` helper (auto-open decision + deep-link URL); an `OnboardingView` that reuses the existing `PermissionMonitor` for live trust status; `DkeySettings.hasCompletedOnboarding` + `AppState` gate; a `Window` scene opened at launch. The engine is untouched.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit (macOS 14), XCTest, XcodeGen.

## Global Constraints

- `Sources/App/` only — no engine change; reuse `PermissionMonitor` (do not reimplement trust polling).
- Palette (from `DKey Mockups.standalone.html`): windowBg `#faf9f5`, panel `#f5f5f7`, text `#1d1d1f`, secondary `#86868b`, accent `#5ba7f7`, success `#28c840`.
- Accessibility deep link: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
- `hasCompletedOnboarding` defaults `false`, decoded via `decodeIfPresent ?? false` (backward-compat, mirroring existing `DkeySettings` fields). Auto-open onboarding at launch iff `!hasCompletedOnboarding`; finishing/"Để sau" sets it true.
- No regression: all prior tests (133 on `main`) stay green. XcodeGen: `xcodegen generate` after new files; `dkey.xcodeproj` gitignored (never commit). Work on `feature/redesign-onboarding` (already created), commit per task.

---

## File Structure

- `Sources/App/Theme.swift` *(new)* — `Color(hex:)` + named palette colors.
- `Sources/App/Onboarding.swift` *(new)* — pure `shouldAutoOpen` + deep-link URL.
- `Sources/App/DkeySettings.swift` *(modify)* — `hasCompletedOnboarding` field.
- `Sources/App/AppState.swift` *(modify)* — publish `hasCompletedOnboarding` + `completeOnboarding()`.
- `Sources/App/Views/OnboardingView.swift` *(new)* — the onboarding screen.
- `Sources/App/DkeyApp.swift` *(modify)* — onboarding `Window` scene + auto-open at launch.
- `Tests/AppTests/ThemeTests.swift`, `Tests/AppTests/OnboardingTests.swift` *(new)*.

---

## Task 1: Theme (palette) + Onboarding helper

**Files:**
- Create: `Sources/App/Theme.swift`, `Sources/App/Onboarding.swift`
- Create: `Tests/AppTests/ThemeTests.swift`, `Tests/AppTests/OnboardingTests.swift`

**Interfaces:**
- Produces: `extension Color { init(hex: UInt32) }` + `static let dkWindowBg/dkPanel/dkText/dkSecondary/dkAccent/dkSuccess: Color`.
- Produces: `enum Onboarding { static func shouldAutoOpen(completed: Bool) -> Bool; static let accessibilitySettingsURL: URL }`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/AppTests/ThemeTests.swift`:

```swift
import SwiftUI
import XCTest
@testable import dkey

final class ThemeTests: XCTestCase {
    private func rgb(_ c: Color) -> (r: Double, g: Double, b: Double) {
        let n = NSColor(c).usingColorSpace(.sRGB)!
        return (Double(n.redComponent), Double(n.greenComponent), Double(n.blueComponent))
    }

    func testHexInit() {
        let c = rgb(Color(hex: 0xFAF9F5))
        XCTAssertEqual(c.r, 0xFA/255, accuracy: 0.01)
        XCTAssertEqual(c.g, 0xF9/255, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xF5/255, accuracy: 0.01)
    }

    func testNamedAccent() {
        let c = rgb(Color.dkAccent)  // #5ba7f7
        XCTAssertEqual(c.r, 0x5B/255, accuracy: 0.01)
        XCTAssertEqual(c.g, 0xA7/255, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xF7/255, accuracy: 0.01)
    }
}
```

Create `Tests/AppTests/OnboardingTests.swift`:

```swift
import XCTest
@testable import dkey

final class OnboardingTests: XCTestCase {
    func testAutoOpenWhenNotCompleted() {
        XCTAssertTrue(Onboarding.shouldAutoOpen(completed: false))
        XCTAssertFalse(Onboarding.shouldAutoOpen(completed: true))
    }

    func testDeepLinkURL() {
        XCTAssertEqual(Onboarding.accessibilitySettingsURL.scheme, "x-apple.systempreferences")
        XCTAssertTrue(Onboarding.accessibilitySettingsURL.absoluteString.contains("Privacy_Accessibility"))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd /Users/dat.nguyenmanh/Desktop/dat/my-git/dkey && xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: compile failure — `Color(hex:)` / `Onboarding` undefined.

- [ ] **Step 3: Implement**

Create `Sources/App/Theme.swift`:

```swift
import SwiftUI

extension Color {
    /// 0xRRGGBB → Color (sRGB).
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255,
                  opacity: 1)
    }

    // Palette from DKey Mockups.standalone.html
    static let dkWindowBg  = Color(hex: 0xFAF9F5)
    static let dkPanel     = Color(hex: 0xF5F5F7)
    static let dkText      = Color(hex: 0x1D1D1F)
    static let dkSecondary = Color(hex: 0x86868B)
    static let dkAccent    = Color(hex: 0x5BA7F7)
    static let dkSuccess   = Color(hex: 0x28C840)
}
```

Create `Sources/App/Onboarding.swift`:

```swift
import Foundation

/// Pure onboarding decisions + the Accessibility deep link.
enum Onboarding {
    /// Auto-open onboarding at launch only until the user has finished it once.
    static func shouldAutoOpen(completed: Bool) -> Bool { !completed }

    /// Deep link to System Settings ▸ Privacy & Security ▸ Accessibility.
    static let accessibilitySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
}
```

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: `TEST SUCCEEDED` — new tests pass, prior 133 green.

- [ ] **Step 5: Commit**

```bash
git add Sources/App/Theme.swift Sources/App/Onboarding.swift Tests/AppTests/ThemeTests.swift Tests/AppTests/OnboardingTests.swift
git commit -m "feat(app): Theme palette + Onboarding helper"
```
(Do NOT `git add dkey.xcodeproj` — gitignored.)

---

## Task 2: hasCompletedOnboarding in DkeySettings + AppState

**Files:**
- Modify: `Sources/App/DkeySettings.swift`, `Sources/App/AppState.swift`
- Modify: `Tests/AppTests/SettingsStoreTests.swift`

**Interfaces:**
- Produces: `DkeySettings.hasCompletedOnboarding: Bool`; `AppState.hasCompletedOnboarding` (`@Published`); `AppState.completeOnboarding()`.

- [ ] **Step 1: Add the field to DkeySettings**

In `Sources/App/DkeySettings.swift`:
- Add `var hasCompletedOnboarding: Bool` to the struct (after `useSmartSwitchKey`).
- Add `hasCompletedOnboarding: false` to `defaults`.
- Add `hasCompletedOnboarding` to `CodingKeys`.
- In `init(from:)`: `hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false`.

- [ ] **Step 2: Wire AppState**

In `Sources/App/AppState.swift`:
- Add `@Published var hasCompletedOnboarding: Bool = false { didSet { if !_isReflecting { persist() } } }`.
- In `persist()`, add `hasCompletedOnboarding: hasCompletedOnboarding` to the `DkeySettings(...)` call.
- In `init`, under `_isReflecting = true`, add `hasCompletedOnboarding = s.hasCompletedOnboarding`.
- Add:
```swift
    func completeOnboarding() {
        if !hasCompletedOnboarding { hasCompletedOnboarding = true }  // didSet persists
    }
```

- [ ] **Step 3: Extend the round-trip test**

In `Tests/AppTests/SettingsStoreTests.swift`, in `testRoundTrip`, add `s.hasCompletedOnboarding = true` (with the other field assignments) so it's covered by the save→load assertion.

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: `TEST SUCCEEDED` — round-trip covers the new field; all prior green.

- [ ] **Step 5: Commit**

```bash
git add Sources/App/DkeySettings.swift Sources/App/AppState.swift Tests/AppTests/SettingsStoreTests.swift
git commit -m "feat(app): persist hasCompletedOnboarding + completeOnboarding()"
```

---

## Task 3: OnboardingView + window + auto-open

**Files:**
- Create: `Sources/App/Views/OnboardingView.swift`
- Modify: `Sources/App/DkeyApp.swift`

**Interfaces:**
- Consumes: `Color.dk*`, `Onboarding.shouldAutoOpen/accessibilitySettingsURL`, `AppState.hasCompletedOnboarding/completeOnboarding`, `PermissionMonitor.isTrusted/waitUntilTrusted`.

- [ ] **Step 1: Build the view**

Create `Sources/App/Views/OnboardingView.swift`:

```swift
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
```

- [ ] **Step 2: Add the window scene + auto-open**

In `Sources/App/DkeyApp.swift`:
- Add a window scene inside `body` (after the settings `Window`):
```swift
        Window("Chào mừng", id: "onboarding") {
            OnboardingView().environmentObject(state)
        }
        .windowResizability(.contentSize)
```
- In `MenuBarLabel` (which already has `@Environment(\.openWindow)` + a startup guard for show-UI-on-startup), extend the `.onAppear` startup block to ALSO auto-open onboarding first when needed. Update `MenuBarLabel`:
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
                if Onboarding.shouldAutoOpen(completed: state.hasCompletedOnboarding) {
                    openWindow(id: "onboarding")
                    NSApp.activate(ignoringOtherApps: true)
                } else if state.showUIOnStartup {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
    }
}
```
(Onboarding takes precedence over show-UI-on-startup at first run; after onboarding is completed, the show-UI-on-startup behaviour resumes on later launches.)

- [ ] **Step 3: Regenerate + build**

Run: `xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug build 2>&1 | tail -8`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Full test pass (regression gate)**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -8`
Expected: `TEST SUCCEEDED` — all prior + Task 1/2 tests green (this task adds no automated tests; it's a view + window).

- [ ] **Step 5: Manual smoke (deferred to user)**

Fresh state (reset defaults or first run): launch → Onboarding window opens with logo + "Cấp quyền Trợ năng". Click "Mở System Settings" → Accessibility pane opens; grant → the card flips to green "Đã cấp quyền" live. Click "Bắt đầu" → window closes. Relaunch → onboarding does NOT reopen (and show-UI-on-startup behaves as before). Colors match the warm mockup palette.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/Views/OnboardingView.swift Sources/App/DkeyApp.swift
git commit -m "feat(app): Onboarding window + first-run auto-open"
```

---

## Self-Review

**1. Spec coverage:**
- Theme palette → Task 1. ✅
- Onboarding auto-open decision + deep-link → Task 1. ✅
- `hasCompletedOnboarding` persist + `completeOnboarding()` → Task 2. ✅
- Onboarding view (welcome + grant card + live status + Bắt đầu/Để sau) → Task 3. ✅
- Window scene + first-run auto-open (precedence over show-UI-on-startup) → Task 3. ✅
- Reuse PermissionMonitor / engine untouched / no regression → all tasks' test steps. ✅

**2. Placeholder scan:** No TBD/TODO; every code step shows complete code. Task 2's AppState/DkeySettings edits are described against the exact existing `_isReflecting`/`persist()`/`init`/decoder pattern with concrete lines.

**3. Type consistency:** `Color.dk*` + `Onboarding.shouldAutoOpen/accessibilitySettingsURL` (Task 1) used in `OnboardingView` + `MenuBarLabel` (Task 3). `AppState.hasCompletedOnboarding`/`completeOnboarding()` (Task 2) consumed by `OnboardingView`/`MenuBarLabel` (Task 3). `DkeySettings.hasCompletedOnboarding` (Task 2) is set in `persist()`/`init`/round-trip test. `PermissionMonitor.isTrusted`/`waitUntilTrusted` are pre-existing. ✅
