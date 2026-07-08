# Screen ⑥ Hệ thống + Giới thiệu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the two final settings tabs (Hệ thống `SystemView`, Giới thiệu `AboutView`) into the mockup's card style, wire "Kiểm tra cập nhật" to the GitHub Releases page, and render three unbacked features as disabled placeholders.

**Architecture:** A pure helper `SystemExtras.placeholderRows` lists the two disabled toggle placeholders. `SystemView` becomes two `SectionCard`s (backed toggles via `ToggleRow`, two disabled toggle placeholders, one dimmed per-app-list placeholder) plus the reset button/dialog. `AboutView` becomes a card with version/credit/links plus a new "Kiểm tra cập nhật" button opening the Releases URL. No engine, `AppState`, or model changes.

**Tech Stack:** SwiftUI + AppKit, macOS 14.0, Swift 5.9, XcodeGen, XCTest.

## Global Constraints

- **Engine untouched.** No file under `Sources/Engine` or `Sources/Platform`. No `AppState`/`DkeySettings`/`SmartSwitch`/`AppInfo` change. `SettingsComponents.swift`, `Theme.swift`, `SettingsRootView.swift` NOT modified.
- **Reuse existing primitives & Theme:** `SectionCard(title:content:)`, `ToggleRow(title:subtitle:isOn:enabled:)`; colors `Color.dkWindowBg / dkPanel / dkText / dkSecondary`. Do NOT redefine them.
- **Run `xcodegen generate` after adding ANY new source/test file** (regenerates the gitignored `dkey.xcodeproj`); else it is absent from the target and tests crash-loop.
- **Placeholders must be inert:** the two placeholder toggles bind to `.constant(false)` with `enabled: false`; the per-app placeholder row uses `.allowsHitTesting(false)` + dim. None may mutate state.
- **Preserve backed behavior:** the backed toggles keep their exact `AppState` bindings; `resetToDefaults()` + the `confirmationDialog` behavior is unchanged; the existing About source links keep working.
- **Verbatim UI copy:** card titles `"Hệ thống"`, `"Cài đặt theo ứng dụng"`, `"Giới thiệu"`; backed toggles `"Khởi động cùng macOS"`, `"Hiện cửa sổ Cài đặt khi khởi động"`, `"Biểu tượng đơn sắc trên menu bar"`, `"Hiện biểu tượng ở Dock"`, `"Chuyển chế độ thông minh"` (subtitle `"Tự nhớ chế độ Việt/Anh của từng ứng dụng khi chuyển qua lại"`); placeholders `"Sửa lỗi autocorrect trên trình duyệt"`, `"Ghi nhớ bảng mã theo ứng dụng"` (subtitle `"Hữu ích với Photoshop, CAD… dùng VNI, TCVN3"`), per-app row `"Cấu hình từng ứng dụng — sắp có"`; reset `"Khôi phục cài đặt mặc định"`, dialog `"Khôi phục toàn bộ cài đặt về mặc định?"` / `"Khôi phục"` / `"Huỷ"`; About `"dkey"`, `"Bộ gõ Tiếng Việt cho macOS"`, `"Phiên bản \(AppInfo.displayVersion)"`, `"Giấy phép GPL v3 · Engine port từ OpenKey (Tuyen Mai)"`, buttons `"Mã nguồn dkey"`, `"OpenKey"`, `"Kiểm tra cập nhật"`.
- **Existing interfaces (consume, do not change):**
  - `AppState.runOnStartup/showUIOnStartup/grayIcon/showIconOnDock/useSmartSwitchKey: Bool` (@Published), `AppState.resetToDefaults()`.
  - `AppInfo.displayVersion: String`.
- **Update URL:** `https://github.com/datnm555/dkey/releases`. Existing links: dkey `https://github.com/datnm555/dkey`, OpenKey `https://github.com/tuyenvm/OpenKey`.
- **Test/build command** (repo root): `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`. If a build shows entitlements "modified during build" or stale-file errors, `rm -rf build` (DerivedData) and retry.

---

### Task 1: `SystemExtras.placeholderRows` pure helper

Pure, testable data for the two disabled toggle placeholders. No SwiftUI.

**Files:**
- Create: `Sources/App/SystemExtras.swift`
- Test: `Tests/AppTests/SystemExtrasTests.swift`

**Interfaces:**
- Produces:
  - `enum SystemExtras`
  - `struct SystemExtras.Row: Equatable { let title: String; let subtitle: String?; let enabled: Bool }`
  - `static var SystemExtras.placeholderRows: [Row]` → exactly 2 rows in mockup order, every `enabled == false`; only index 1 ("Ghi nhớ bảng mã theo ứng dụng") has a subtitle. `SystemView` (Task 2) renders `ToggleRow`s from this.

- [ ] **Step 1: Write the failing test**

Create `Tests/AppTests/SystemExtrasTests.swift`:

```swift
import XCTest
@testable import dkey

final class SystemExtrasTests: XCTestCase {
    func testTwoRowsInMockupOrder() {
        XCTAssertEqual(SystemExtras.placeholderRows.map(\.title), [
            "Sửa lỗi autocorrect trên trình duyệt",
            "Ghi nhớ bảng mã theo ứng dụng",
        ])
    }

    func testAllRowsDisabled() {
        XCTAssertTrue(SystemExtras.placeholderRows.allSatisfy { !$0.enabled })
    }

    func testOnlySecondRowHasSubtitle() {
        let rows = SystemExtras.placeholderRows
        XCTAssertNil(rows[0].subtitle)
        XCTAssertEqual(rows[1].subtitle, "Hữu ích với Photoshop, CAD… dùng VNI, TCVN3")
    }
}
```

- [ ] **Step 2: Regenerate the project so the new test file is in the target**

Run: `xcodegen generate`
Expected: `Created project at .../dkey.xcodeproj`

- [ ] **Step 3: Run the test to verify it fails**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: BUILD FAILED — `cannot find 'SystemExtras' in scope`.

- [ ] **Step 4: Write the minimal implementation**

Create `Sources/App/SystemExtras.swift`:

```swift
/// Pure model for the Hệ thống tab's deferred (unbacked) toggle rows (screen ⑥).
/// Both are UI placeholders — no engine backing yet — so `enabled` is false.
enum SystemExtras {
    struct Row: Equatable {
        let title: String
        let subtitle: String?
        let enabled: Bool
    }

    /// The two disabled toggle placeholders, in mockup order.
    static var placeholderRows: [Row] {
        [
            Row(title: "Sửa lỗi autocorrect trên trình duyệt", subtitle: nil, enabled: false),
            Row(title: "Ghi nhớ bảng mã theo ứng dụng",
                subtitle: "Hữu ích với Photoshop, CAD… dùng VNI, TCVN3", enabled: false),
        ]
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **` — 152 tests (149 existing + 3 new), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/SystemExtras.swift Tests/AppTests/SystemExtrasTests.swift project.yml
git commit -m "feat(app): SystemExtras.placeholderRows pure helper for Hệ thống tab"
```

---

### Task 2: Restyle `SystemView` into cards

Rewrite the Hệ thống tab. SwiftUI view rewrite — verified by a clean build + full suite green.

**Files:**
- Modify (rewrite): `Sources/App/Views/SystemView.swift`

**Interfaces:**
- Consumes: `SystemExtras.placeholderRows` (Task 1); `SectionCard`, `ToggleRow`; `Color.dk*`; `AppState.runOnStartup/showUIOnStartup/grayIcon/showIconOnDock/useSmartSwitchKey`, `AppState.resetToDefaults()`.
- Produces: rewritten `struct SystemView: View` (still hosted by `SettingsRootView` `.system` case).

- [ ] **Step 1: Rewrite the view**

Replace the entire contents of `Sources/App/Views/SystemView.swift` with:

```swift
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
```

- [ ] **Step 2: Regenerate the project (no new file, keep the flow consistent)**

Run: `xcodegen generate`
Expected: `Created project at .../dkey.xcodeproj`

- [ ] **Step 3: Build + run the full suite**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **`, 152 tests, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/Views/SystemView.swift
git commit -m "feat(app): redesign Hệ thống tab into cards with placeholders (screen ⑥)"
```

---

### Task 3: Restyle `AboutView` + add "Kiểm tra cập nhật"

Rewrite the Giới thiệu tab into a card and add the update button. SwiftUI view rewrite — verified by a clean build + full suite green.

**Files:**
- Modify (rewrite): `Sources/App/Views/AboutView.swift`

**Interfaces:**
- Consumes: `SectionCard`; `Color.dk*`; `AppInfo.displayVersion`.
- Produces: rewritten `struct AboutView: View` (still hosted by `SettingsRootView` `.about` case).

- [ ] **Step 1: Rewrite the view**

Replace the entire contents of `Sources/App/Views/AboutView.swift` with:

```swift
import SwiftUI
import AppKit

struct AboutView: View {
    private let dkeyURL = URL(string: "https://github.com/datnm555/dkey")!
    private let openKeyURL = URL(string: "https://github.com/tuyenvm/OpenKey")!
    private let releasesURL = URL(string: "https://github.com/datnm555/dkey/releases")!

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: "Giới thiệu") {
                    VStack(spacing: 10) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable().frame(width: 64, height: 64)
                        Text("dkey").font(.title).bold().foregroundStyle(Color.dkText)
                        Text("Bộ gõ Tiếng Việt cho macOS")
                            .foregroundStyle(Color.dkSecondary)
                        Text("Phiên bản \(AppInfo.displayVersion)")
                            .font(.callout).foregroundStyle(Color.dkSecondary)

                        Divider().frame(maxWidth: 260).padding(.vertical, 4)

                        Text("Giấy phép GPL v3 · Engine port từ OpenKey (Tuyen Mai)")
                            .font(.footnote).foregroundStyle(Color.dkSecondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button("Mã nguồn dkey") { NSWorkspace.shared.open(dkeyURL) }
                            Button("OpenKey") { NSWorkspace.shared.open(openKeyURL) }
                            Button("Kiểm tra cập nhật") { NSWorkspace.shared.open(releasesURL) }
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dkWindowBg)
    }
}
```

- [ ] **Step 2: Regenerate the project (no new file, keep the flow consistent)**

Run: `xcodegen generate`
Expected: `Created project at .../dkey.xcodeproj`

- [ ] **Step 3: Build + run the full suite**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **`, 152 tests, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/Views/AboutView.swift
git commit -m "feat(app): redesign Giới thiệu tab into a card + Kiểm tra cập nhật (screen ⑥)"
```

---

## Manual smoke (deferred to user)

Open Settings → Hệ thống + Giới thiệu tabs:
1. Hệ thống: two cards on the warm bg; the backed toggles (Khởi động cùng macOS / Hiện cửa sổ / Biểu tượng đơn sắc / Hiện ở Dock / Chuyển chế độ thông minh) all work; the two placeholder toggles + the "Cấu hình từng ứng dụng — sắp có" row are dimmed and inert.
2. "Khôi phục cài đặt mặc định" opens the confirmation dialog; "Khôi phục" resets, "Huỷ" cancels.
3. Giới thiệu: card with icon, "dkey", version, GPL/OpenKey credit; "Mã nguồn dkey"/"OpenKey" open their repos; "Kiểm tra cập nhật" opens the Releases page.

---

## Self-Review

**1. Spec coverage:**
- Pure `SystemExtras.placeholderRows` (2 disabled rows; only [1] has subtitle) → Task 1. ✅
- SystemView two cards: backed toggles + 2 disabled placeholders + per-app dimmed row + reset button/dialog → Task 2. ✅
- AboutView card + version/credit/links + "Kiểm tra cập nhật" → Releases → Task 3. ✅
- Placeholders inert (`.constant(false)`+`enabled:false`; per-app `.allowsHitTesting(false)`) → Task 2. ✅
- Backed bindings + reset flow preserved → Task 2 (same bindings, same dialog). ✅
- Theme-only colors; engine/model/SmartSwitch/AppInfo/SettingsComponents/Theme/SettingsRootView untouched → Global Constraints. ✅
- 149 existing tests stay green + 3 new → Task 1 Step 5 (152). ✅

**2. Placeholder scan:** No TBD/TODO; full code in every code step; commands have expected output. ✅

**3. Type consistency:** `SystemExtras.Row { title; subtitle: String?; enabled }` defined in Task 1, consumed identically in Task 2 (`.title`/`.subtitle`/`.enabled`). `ToggleRow(title:subtitle:isOn:enabled:)` / `SectionCard(title:content:)` signatures match their call sites. `AppState` binding names (`runOnStartup`/`showUIOnStartup`/`grayIcon`/`showIconOnDock`/`useSmartSwitchKey`) and `resetToDefaults()` match the current `AppState`. `placeholderRows` name identical across tasks. ✅
