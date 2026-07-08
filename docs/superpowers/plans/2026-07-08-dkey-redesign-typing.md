# Screen ③ Kiểu gõ (settings tab) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the Kiểu gõ settings tab into the mockup's card + toggle-row style (screen 1b): keep the three working controls, add a "Gõ tiếng Việt" section of five disabled placeholder rows, and introduce two reusable settings primitives (`SectionCard`, `ToggleRow`) for the remaining tabs.

**Architecture:** A pure helper `TypingExtras.placeholderRows` describes the five deferred rows as data. Two reusable SwiftUI views — `SectionCard` (titled rounded panel) and `ToggleRow` (title/subtitle + trailing Toggle, dims + inert when disabled) — provide the mockup card language. `TypingSettingsView` is rewritten to a `ScrollView` of two `SectionCard`s consuming them. No engine, `AppState`, or `DkeySettings` changes; the five rows are inert placeholders bound to `.constant(false)`.

**Tech Stack:** SwiftUI + AppKit, macOS 14.0, Swift 5.9, XcodeGen, XCTest.

## Global Constraints

- **Engine untouched.** No file under `Sources/Engine` or `Sources/Platform`. No `AppState`/`DkeySettings` model field added or changed. `SettingsRootView.swift` and `Theme.swift` are NOT modified.
- **Reuse `Theme`** — use existing `Color.dkWindowBg / dkPanel / dkText / dkSecondary / dkAccent / dkSuccess`; do NOT redefine colors.
- **Run `xcodegen generate` after adding ANY new source/test file** (regenerates the gitignored `dkey.xcodeproj`); otherwise the file is absent from the target and tests crash-loop.
- **The five placeholder rows must be inert** — bound to `.constant(false)` and `.disabled(true)` (via `ToggleRow.enabled == false`); they must NOT mutate any state.
- **Reusable views must not depend on `AppState`** — `SectionCard` and `ToggleRow` take their data via parameters/bindings only.
- **Verbatim UI copy** (exact, including the ellipsis character `…`):
  - Card titles: `"Kiểu gõ"`, `"Gõ tiếng Việt"`.
  - Control labels: `"Kiểu gõ"`, `"Kiểu bỏ dấu"`, `"Phím chuyển"`; segments `"Telex"`, `"VNI"`; orthography `"Mới (hoà, uý)"`, `"Cũ (hòa, úy)"`.
  - Five rows in order: `"Kiểm tra chính tả"`, `"Khôi phục phím nếu từ sai"`, `"Viết hoa chữ cái đầu câu"`, `"Gõ nhanh Telex"`, `"Cho phép f, z, w, j làm phụ âm đầu"`.
  - Quick-Telex subtitle: `"cc = ch, gg = gi, kk = kh, nn = ng…"`.
- **Existing interfaces (consume, do not change):**
  - `AppState.inputMethod: InputMethod` (@Published), `AppState.useModernOrthography: Bool` (@Published), `AppState.switchKeyStatus: Int32` (@Published).
  - `enum InputMethod { case telex; case vni }`.
  - `struct KeyRecorderField: View` with `@Binding var status: Int32` → construct as `KeyRecorderField(status: $binding)`.
- **Test/build command** (repo root): `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`. If a build shows entitlements "modified during build" or stale-file errors, `rm -rf build` (DerivedData) and retry.

---

### Task 1: `TypingExtras.placeholderRows` pure helper

Pure, testable data describing the five deferred rows. No SwiftUI.

**Files:**
- Create: `Sources/App/TypingExtras.swift`
- Test: `Tests/AppTests/TypingExtrasTests.swift`

**Interfaces:**
- Produces:
  - `enum TypingExtras`
  - `struct TypingExtras.Row: Equatable { let title: String; let subtitle: String?; let enabled: Bool }`
  - `static var TypingExtras.placeholderRows: [Row]` → exactly 5 rows in mockup order, every `enabled == false`; only index 3 ("Gõ nhanh Telex") has a non-nil `subtitle`. `TypingSettingsView` (Task 2) renders `ToggleRow`s from this.

- [ ] **Step 1: Write the failing test**

Create `Tests/AppTests/TypingExtrasTests.swift`:

```swift
import XCTest
@testable import dkey

final class TypingExtrasTests: XCTestCase {
    func testFiveRowsInMockupOrder() {
        XCTAssertEqual(TypingExtras.placeholderRows.map(\.title), [
            "Kiểm tra chính tả",
            "Khôi phục phím nếu từ sai",
            "Viết hoa chữ cái đầu câu",
            "Gõ nhanh Telex",
            "Cho phép f, z, w, j làm phụ âm đầu",
        ])
    }

    func testAllRowsDisabled() {
        XCTAssertTrue(TypingExtras.placeholderRows.allSatisfy { !$0.enabled })
    }

    func testOnlyQuickTelexHasSubtitle() {
        let rows = TypingExtras.placeholderRows
        XCTAssertEqual(rows[3].subtitle, "cc = ch, gg = gi, kk = kh, nn = ng…")
        let others = rows.enumerated().filter { $0.offset != 3 }.map(\.element)
        XCTAssertTrue(others.allSatisfy { $0.subtitle == nil })
    }
}
```

- [ ] **Step 2: Regenerate the project so the new test file is in the target**

Run: `xcodegen generate`
Expected: `Created project at .../dkey.xcodeproj`

- [ ] **Step 3: Run the test to verify it fails**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: BUILD FAILED — `cannot find 'TypingExtras' in scope`.

- [ ] **Step 4: Write the minimal implementation**

Create `Sources/App/TypingExtras.swift`:

```swift
/// Pure model for the Kiểu gõ tab's deferred typing-extra rows (screen ③).
/// All five are UI placeholders — no engine backing yet — so `enabled` is false.
enum TypingExtras {
    struct Row: Equatable {
        let title: String
        let subtitle: String?
        let enabled: Bool
    }

    /// The five "Gõ tiếng Việt" rows, in mockup order. All disabled placeholders.
    static var placeholderRows: [Row] {
        [
            Row(title: "Kiểm tra chính tả", subtitle: nil, enabled: false),
            Row(title: "Khôi phục phím nếu từ sai", subtitle: nil, enabled: false),
            Row(title: "Viết hoa chữ cái đầu câu", subtitle: nil, enabled: false),
            Row(title: "Gõ nhanh Telex", subtitle: "cc = ch, gg = gi, kk = kh, nn = ng…", enabled: false),
            Row(title: "Cho phép f, z, w, j làm phụ âm đầu", subtitle: nil, enabled: false),
        ]
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **` — 143 tests (140 existing + 3 new), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/TypingExtras.swift Tests/AppTests/TypingExtrasTests.swift project.yml
git commit -m "feat(app): TypingExtras.placeholderRows pure helper for Kiểu gõ tab"
```

---

### Task 2: `SectionCard` + `ToggleRow` primitives and rewritten `TypingSettingsView`

Build the two reusable settings views and rewrite the tab to consume them plus `TypingExtras.placeholderRows`. SwiftUI views + a view rewrite — verified by a clean build and the full suite staying green (visual behaviour deferred to manual smoke).

**Files:**
- Create: `Sources/App/Views/SettingsComponents.swift`
- Modify (rewrite): `Sources/App/Views/TypingSettingsView.swift`

**Interfaces:**
- Consumes: `TypingExtras.placeholderRows` / `TypingExtras.Row` (Task 1); `Color.dk*` (Theme); `AppState.inputMethod`, `AppState.useModernOrthography`, `AppState.switchKeyStatus`; `KeyRecorderField(status:)`; `InputMethod.telex`/`.vni`.
- Produces:
  - `struct SectionCard<Content: View>: View` — `init(title: String, @ViewBuilder content: () -> Content)`.
  - `struct ToggleRow: View` — `init(title: String, subtitle: String? = nil, isOn: Binding<Bool>, enabled: Bool = true)`.
  Both reused by screens ④⑤⑥.

- [ ] **Step 1: Create the reusable primitives**

Create `Sources/App/Views/SettingsComponents.swift`:

```swift
import SwiftUI

/// A titled rounded panel matching the mockup's card style. Reusable across
/// the settings tabs (screens ③–⑥).
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.dkSecondary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dkPanel, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// A settings row: title + optional subtitle on the left, a Toggle on the right.
/// When `enabled` is false the row dims and the toggle is inert (placeholder).
struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var enabled: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dkText)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dkSecondary)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .opacity(enabled ? 1 : 0.5)
        .disabled(!enabled)
    }
}
```

- [ ] **Step 2: Rewrite the Kiểu gõ tab**

Replace the entire contents of `Sources/App/Views/TypingSettingsView.swift` with:

```swift
import SwiftUI

struct TypingSettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: "Kiểu gõ") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kiểu gõ")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dkText)
                            Picker("", selection: $state.inputMethod) {
                                Text("Telex").tag(InputMethod.telex)
                                Text("VNI").tag(InputMethod.vni)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kiểu bỏ dấu")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dkText)
                            Picker("", selection: $state.useModernOrthography) {
                                Text("Mới (hoà, uý)").tag(true)
                                Text("Cũ (hòa, úy)").tag(false)
                            }
                            .labelsHidden()
                            .pickerStyle(.radioGroup)
                        }
                        HStack {
                            Text("Phím chuyển")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dkText)
                            Spacer()
                            KeyRecorderField(status: $state.switchKeyStatus)
                        }
                    }
                }

                SectionCard(title: "Gõ tiếng Việt") {
                    VStack(spacing: 10) {
                        ForEach(TypingExtras.placeholderRows, id: \.title) { row in
                            ToggleRow(title: row.title,
                                      subtitle: row.subtitle,
                                      isOn: .constant(false),
                                      enabled: row.enabled)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dkWindowBg)
    }
}
```

- [ ] **Step 3: Regenerate the project so the new component file is in the target**

Run: `xcodegen generate`
Expected: `Created project at .../dkey.xcodeproj`

- [ ] **Step 4: Build + run the full suite**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **`, 143 tests, 0 failures. (No stale references; `SectionCard`/`ToggleRow`/`TypingSettingsView` compile.)

- [ ] **Step 5: Commit**

```bash
git add Sources/App/Views/SettingsComponents.swift Sources/App/Views/TypingSettingsView.swift project.yml
git commit -m "feat(app): redesign Kiểu gõ tab with SectionCard/ToggleRow primitives (screen ③)"
```

---

## Manual smoke (deferred to user)

Open the Settings window (Cài đặt… from the popover) → Kiểu gõ tab:
1. Two cards render in the warm `#faf9f5` background, panel `#f5f5f7` cards.
2. **Kiểu gõ** segmented Telex/VNI changes the typing method; **Kiểu bỏ dấu** Mới/Cũ toggles orthography; **Phím chuyển** recorder captures a new key — all still work.
3. The **Gõ tiếng Việt** card shows five rows; "Gõ nhanh Telex" has the `cc = ch…` subtitle; all five are dimmed and their toggles do not respond to clicks.

---

## Self-Review

**1. Spec coverage:**
- Two reusable primitives `SectionCard` + `ToggleRow` → Task 2 Step 1. ✅
- Pure `TypingExtras.placeholderRows` → Task 1. ✅
- Rewritten `TypingSettingsView` (2 cards; 3 working controls + 5 disabled rows) → Task 2 Step 2. ✅
- Inert placeholders (`.constant(false)` + `enabled: false` → `.disabled`) → Task 2 Steps 1–2. ✅
- Reusable views independent of AppState (params/bindings only) → `SectionCard`/`ToggleRow` signatures. ✅
- Theme-only colors → Global Constraints; only `Color.dk*` used. ✅
- Engine / AppState / DkeySettings / SettingsRootView / Theme untouched → not in either task's Files. ✅
- 140 existing tests stay green + 3 new → Task 1 Step 5, Task 2 Step 4 (143). ✅

**2. Placeholder scan:** No TBD/TODO; every code step shows full code; commands have expected output. ✅

**3. Type consistency:** `TypingExtras.Row { title; subtitle: String?; enabled }` defined in Task 1, consumed identically in Task 2 (`row.title`, `row.subtitle`, `row.enabled`). `ToggleRow(title:subtitle:isOn:enabled:)` and `SectionCard(title:content:)` signatures match their call sites in Task 2 Step 2. `ForEach(..., id: \.title)` uses the `String` title (stable). `placeholderRows` name identical across tasks. ✅
