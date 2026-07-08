# Screen ② Bảng điều khiển chính (popover) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the plain native menu-bar dropdown with a custom Theme-styled popover (screen 1a of the mockup): DKey header, Tiếng Việt master toggle + switch-key subtitle, Kiểu gõ segmented control, disabled Bảng mã placeholder, and a Cài đặt/Thoát footer.

**Architecture:** Switch `MenuBarExtra` to `.menuBarExtraStyle(.window)` so it renders a custom SwiftUI view instead of a native menu. A new pure helper `ControlPanel.inputMethodSegments` describes the three Kiểu gõ segments (Telex/VNI live, Simple Telex disabled). A new `ControlPanelView` renders the popover, binding to the existing `AppState`. No engine, `AppState`, or `DkeySettings` changes.

**Tech Stack:** SwiftUI + AppKit, macOS 14.0, Swift 5.9, XcodeGen, XCTest.

## Global Constraints

- **Engine untouched.** No file under `Sources/Engine` or `Sources/Platform` changes. No `AppState`/`DkeySettings` model fields added or changed.
- **Reuse `Theme` from screen ①** — use the existing `Color.dkWindowBg / dkPanel / dkText / dkSecondary / dkAccent / dkSuccess`; do NOT redefine colors.
- **Run `xcodegen generate` after adding ANY new source/test file** (regenerates the gitignored `dkey.xcodeproj`); otherwise the file is absent from the target and tests crash-loop. This is a hard project rule.
- **Placeholder controls must be inert.** Simple Telex segment and the Bảng mã row must NOT mutate any state when tapped (they have no backing feature yet).
- **Verbatim UI copy:** `"DKey"`, `"Tiếng Việt"`, `"Phím chuyển nhanh"`, `"Kiểu gõ"`, `"Telex"`, `"VNI"`, `"Simple Telex"`, `"Bảng mã"`, `"Unicode (dựng sẵn)"`, `"Cài đặt…"`, `"Thoát"`.
- **Existing interfaces (consume, do not change):**
  - `AppState.isVietnamese: Bool` (@Published, two-way bindable).
  - `AppState.inputMethod: InputMethod` (@Published; setting it drives the engine + persists via `didSet`).
  - `AppState.switchKeyStatus: Int32` (@Published).
  - `static AppState.hotkeyDescription(_ status: Int32) -> String` → e.g. `"⌥Z"`.
  - `enum InputMethod: String, Codable, CaseIterable { case telex; case vni }`.
  - Window scene id `"settings"` (opened via `@Environment(\.openWindow)`).
- **Test/build command** (from repo root):
  `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
  If a build shows `entitlements "modified during build"` or stale-file errors after branch switches, `rm -rf build` (DerivedData) and retry.

---

### Task 1: `ControlPanel.inputMethodSegments` pure helper

Pure, testable model for the Kiểu gõ segmented control. No SwiftUI — just data.

**Files:**
- Create: `Sources/App/ControlPanel.swift`
- Test: `Tests/AppTests/ControlPanelTests.swift`

**Interfaces:**
- Consumes: `InputMethod` (`.telex`, `.vni`) from `Sources/Engine/InputMethod.swift`.
- Produces:
  - `enum ControlPanel`
  - `struct ControlPanel.Segment: Equatable { let label: String; let method: InputMethod?; let enabled: Bool }`
  - `static var ControlPanel.inputMethodSegments: [Segment]` → exactly 3 items: `Telex`(.telex, enabled), `VNI`(.vni, enabled), `Simple Telex`(nil, disabled). `ControlPanelView` (Task 2) renders from this.

- [ ] **Step 1: Write the failing test**

Create `Tests/AppTests/ControlPanelTests.swift`:

```swift
import XCTest
@testable import dkey

final class ControlPanelTests: XCTestCase {
    func testSegmentCountAndLabels() {
        let segs = ControlPanel.inputMethodSegments
        XCTAssertEqual(segs.count, 3)
        XCTAssertEqual(segs.map(\.label), ["Telex", "VNI", "Simple Telex"])
    }

    func testTelexAndVniAreEnabledWithMethod() {
        let segs = ControlPanel.inputMethodSegments
        XCTAssertEqual(segs[0].method, .telex)
        XCTAssertTrue(segs[0].enabled)
        XCTAssertEqual(segs[1].method, .vni)
        XCTAssertTrue(segs[1].enabled)
    }

    func testSimpleTelexIsDisabledPlaceholder() {
        let seg = ControlPanel.inputMethodSegments[2]
        XCTAssertNil(seg.method)
        XCTAssertFalse(seg.enabled)
    }
}
```

- [ ] **Step 2: Regenerate the project so the new test file is in the target**

Run: `xcodegen generate`
Expected: `Created project at .../dkey.xcodeproj`

- [ ] **Step 3: Run the test to verify it fails**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: BUILD FAILED — `cannot find 'ControlPanel' in scope` (type not defined yet).

- [ ] **Step 4: Write the minimal implementation**

Create `Sources/App/ControlPanel.swift`:

```swift
import Foundation

/// Pure model backing the menu-bar popover (screen ②).
enum ControlPanel {
    /// One Kiểu gõ segment. `method == nil` + `enabled == false` marks a
    /// placeholder whose backing feature isn't built yet (Simple Telex).
    struct Segment: Equatable {
        let label: String
        let method: InputMethod?
        let enabled: Bool
    }

    /// Segments for the Kiểu gõ selector: Telex & VNI are live; Simple Telex
    /// is a disabled placeholder (no engine backing yet).
    static var inputMethodSegments: [Segment] {
        [
            Segment(label: "Telex", method: .telex, enabled: true),
            Segment(label: "VNI", method: .vni, enabled: true),
            Segment(label: "Simple Telex", method: nil, enabled: false),
        ]
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **` — `ControlPanelTests` green; total 140 tests (137 existing + 3 new), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/ControlPanel.swift Tests/AppTests/ControlPanelTests.swift project.yml
git commit -m "feat(app): ControlPanel.inputMethodSegments pure helper for popover Kiểu gõ"
```

---

### Task 2: `ControlPanelView` popover + switch MenuBarExtra to `.window`

Render the popover and wire the menu-bar scene to it. This is a SwiftUI view + one scene edit — verified by a successful build and the full suite staying green (visual behaviour is deferred to manual smoke).

**Files:**
- Create: `Sources/App/Views/ControlPanelView.swift`
- Modify: `Sources/App/DkeyApp.swift` (MenuBarExtra body + `.menuBarExtraStyle(.window)`; delete the old `struct MenuContent`)

**Interfaces:**
- Consumes: `ControlPanel.inputMethodSegments` / `ControlPanel.Segment` (Task 1); `AppState.isVietnamese`, `AppState.inputMethod`, `AppState.switchKeyStatus`, `AppState.hotkeyDescription(_:)`; `Color.dk*` (Theme); window id `"settings"`.
- Produces: `struct ControlPanelView: View` (used as the `MenuBarExtra` content).

- [ ] **Step 1: Create the popover view**

Create `Sources/App/Views/ControlPanelView.swift`:

```swift
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
```

- [ ] **Step 2: Wire the MenuBarExtra to the popover**

In `Sources/App/DkeyApp.swift`, replace the `MenuBarExtra { … } label: { … }` block (currently using `MenuContent()`) with the version using `ControlPanelView()` and add the window style modifier:

```swift
        MenuBarExtra {
            ControlPanelView()
                .environmentObject(state)
        } label: {
            MenuBarLabel()
                .environmentObject(state)
        }
        .menuBarExtraStyle(.window)
```

Then DELETE the entire now-unused `struct MenuContent: View { … }` declaration (the block starting `struct MenuContent: View {` through its closing brace). Leave `MenuBarLabel`, both `Window` scenes, and `DkeyAppDelegate` unchanged.

- [ ] **Step 3: Regenerate the project so the new view file is in the target**

Run: `xcodegen generate`
Expected: `Created project at .../dkey.xcodeproj`

- [ ] **Step 4: Build + run the full suite**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **`, 140 tests, 0 failures. (No `MenuContent` reference errors; `ControlPanelView` compiles.)

- [ ] **Step 5: Commit**

```bash
git add Sources/App/Views/ControlPanelView.swift Sources/App/DkeyApp.swift project.yml
git commit -m "feat(app): redesign menu-bar dropdown as .window popover (screen ②)"
```

---

## Manual smoke (deferred to user)

Run `/Applications/dkey.app` after building/installing:
1. Click the menu-bar icon → a **custom popover** opens (not a native menu), warm `#faf9f5` background, DKey header.
2. Toggle **Tiếng Việt** off/on → the menu-bar icon reflects EN/VN; subtitle shows the configured switch key (default `⌥Z`).
3. Tap **Telex** / **VNI** → selection highlights (accent blue) and typing method changes; **Simple Telex** is dimmed and does nothing when tapped.
4. **Bảng mã** row shows "Unicode (dựng sẵn)", dimmed, non-interactive.
5. **Cài đặt…** opens the settings window and activates the app; **Thoát** quits.

---

## Self-Review

**1. Spec coverage:**
- `.window` style switch → Task 2 Step 2. ✅
- Header (no traffic lights) → Task 2 `header`. ✅
- Master toggle + switch-key subtitle → `masterToggle`. ✅
- Kiểu gõ segmented (Telex/VNI live, Simple Telex disabled) → Task 1 helper + `inputMethodRow`/`segmentButton`. ✅
- Bảng mã disabled placeholder → `codeTableRow` (`.allowsHitTesting(false)`). ✅
- Footer Cài đặt/Thoát → `footer`. ✅
- Pure testable `inputMethodSegments` → Task 1. ✅
- Engine / AppState / DkeySettings untouched → Global Constraints; no such files in either task's Files. ✅
- 137 existing tests stay green + 3 new → Task 1 Step 5, Task 2 Step 4 (140). ✅

**2. Placeholder scan:** No TBD/TODO; every code step shows full code; commands have expected output. ✅

**3. Type consistency:** `ControlPanel.Segment { label; method: InputMethod?; enabled }` defined in Task 1 and consumed identically in Task 2 (`seg.label`, `seg.method`, `seg.enabled`). `seg.method == state.inputMethod` compares `InputMethod?` to `InputMethod` (RHS auto-promoted) — valid Swift; `nil == .telex` is `false`, so disabled Simple Telex never shows selected. `inputMethodSegments` name identical across tasks. ✅
