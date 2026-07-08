# Screen ⑤ Chuyển mã (convert tab) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Chuyển mã (convert) settings tab from a grouped `Form` into the mockup's card style using `SectionCard`/`ToggleRow`, preserving all controls, live conversion, and the `@AppStorage` keys.

**Architecture:** Pure view restyle of `ConvertView`. No new logic — `ConvertTool.convert(...)` (already covered by the convert corpus tests) and every `@AppStorage` key stay exactly as they are. Three `SectionCard`s (Bảng mã / Văn bản nguồn / Kết quả) on the warm `dkWindowBg` background. Single task, verified by a clean build and the full suite staying green.

**Tech Stack:** SwiftUI + AppKit, macOS 14.0, Swift 5.9, XcodeGen, XCTest.

## Global Constraints

- **Engine untouched.** No file under `Sources/Engine` or `Sources/Platform`. No `AppState`/`DkeySettings` change. `SettingsComponents.swift`, `Theme.swift`, `SettingsRootView.swift`, `ConvertTool.swift`, `CodeTable.swift` NOT modified. This task touches ONLY `Sources/App/Views/ConvertView.swift`.
- **Reuse existing primitives & Theme:** `SectionCard(title:content:)`, `ToggleRow(title:subtitle:isOn:enabled:)`; colors `Color.dkWindowBg / dkPanel / dkText / dkSecondary`. Do NOT redefine them.
- **Preserve the `@AppStorage` keys verbatim** (backward compatibility): `"convert.from"` (default `CodeTable.unicode.rawValue`), `"convert.to"` (default `CodeTable.tcvn3.rawValue`), `"convert.case"` (default `CaseMode.keep.rawValue`), `"convert.removeMark"` (default `false`).
- **Keep live conversion** — the result is a computed property `output = ConvertTool.convert(...)`; do NOT add a manual "Chuyển mã" button.
- **Verbatim UI copy:** card titles `"Bảng mã"`, `"Văn bản nguồn"`, `"Kết quả"`; picker labels `"Từ bảng mã"`, `"Sang bảng mã"`, `"Kiểu chữ"`; toggle `"Loại bỏ dấu thanh (tiếng Việt → khong dau)"`; button `"Sao chép kết quả"`.
- **Existing interfaces (consume, do not change):**
  - `enum CodeTable: Int, CaseIterable` with `var displayName: String` and `var rawValue: Int`.
  - `enum CaseMode: Int, CaseIterable` with `var displayName: String`.
  - `ConvertTool.convert(_ text: String, from: CodeTable, to: CodeTable, caseMode: CaseMode, removeMark: Bool) -> String`.
- **Test/build command** (repo root): `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`. If a build shows entitlements "modified during build" or stale-file errors, `rm -rf build` (DerivedData) and retry.

---

### Task 1: Restyle `ConvertView` into cards

Rewrite the view. No new logic, no new test — the deliverable is a clean build + the full 149-test suite staying green (visual behaviour deferred to manual smoke).

**Files:**
- Modify (rewrite): `Sources/App/Views/ConvertView.swift`

**Interfaces:**
- Consumes: `SectionCard`, `ToggleRow` (SettingsComponents.swift); `Color.dk*`; `ConvertTool.convert(_:from:to:caseMode:removeMark:)`; `CodeTable`/`CaseMode` (`.allCases`, `.displayName`, `.rawValue`).
- Produces: rewritten `struct ConvertView: View` (still hosted by `SettingsRootView` `.convert` case).

- [ ] **Step 1: Rewrite the view**

Replace the entire contents of `Sources/App/Views/ConvertView.swift` with:

```swift
import SwiftUI
import AppKit

struct ConvertView: View {
    @AppStorage("convert.from") private var fromRaw = CodeTable.unicode.rawValue
    @AppStorage("convert.to") private var toRaw = CodeTable.tcvn3.rawValue
    @AppStorage("convert.case") private var caseRaw = CaseMode.keep.rawValue
    @AppStorage("convert.removeMark") private var removeMark = false
    @State private var input = ""

    private var output: String {
        ConvertTool.convert(
            input,
            from: CodeTable(rawValue: fromRaw) ?? .unicode,
            to: CodeTable(rawValue: toRaw) ?? .tcvn3,
            caseMode: CaseMode(rawValue: caseRaw) ?? .keep,
            removeMark: removeMark)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: "Bảng mã") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Picker("Từ bảng mã", selection: $fromRaw) {
                                ForEach(CodeTable.allCases, id: \.rawValue) {
                                    Text($0.displayName).tag($0.rawValue)
                                }
                            }
                            Button {
                                let t = fromRaw; fromRaw = toRaw; toRaw = t
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                            }
                            .buttonStyle(.borderless)
                            .help("Hoán đổi bảng mã")
                            Picker("Sang bảng mã", selection: $toRaw) {
                                ForEach(CodeTable.allCases, id: \.rawValue) {
                                    Text($0.displayName).tag($0.rawValue)
                                }
                            }
                        }
                        Picker("Kiểu chữ", selection: $caseRaw) {
                            ForEach(CaseMode.allCases, id: \.rawValue) {
                                Text($0.displayName).tag($0.rawValue)
                            }
                        }
                        ToggleRow(title: "Loại bỏ dấu thanh (tiếng Việt → khong dau)",
                                  isOn: $removeMark)
                    }
                }

                SectionCard(title: "Văn bản nguồn") {
                    TextEditor(text: $input)
                        .font(.body)
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.dkWindowBg, in: RoundedRectangle(cornerRadius: 8))
                }

                SectionCard(title: "Kết quả") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextEditor(text: .constant(output))
                            .font(.body)
                            .frame(minHeight: 110)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.dkWindowBg, in: RoundedRectangle(cornerRadius: 8))
                        Button("Sao chép kết quả") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(output, forType: .string)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dkWindowBg)
    }
}
```

- [ ] **Step 2: Regenerate the project (no new file, keep the flow consistent)**

Run: `xcodegen generate`
Expected: `Created project at .../dkey.xcodeproj` (no target change — ConvertView.swift already in the target; safe to run.)

- [ ] **Step 3: Build + run the full suite**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **`, 149 tests, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/Views/ConvertView.swift
git commit -m "feat(app): redesign Chuyển mã tab into cards (screen ⑤)"
```

---

## Manual smoke (deferred to user)

Open Settings → Chuyển mã tab:
1. Three cards render in the warm `#faf9f5` background.
2. Pick "Từ bảng mã" / "Sang bảng mã"; the ⇄ button swaps them; "Kiểu chữ" and "Loại bỏ dấu thanh" still apply.
3. Type in the source editor → the result editor updates live via `ConvertTool`; "Sao chép kết quả" copies the result to the clipboard.
4. Reopening the tab restores the last-picked tables (AppStorage keys preserved).

---

## Self-Review

**1. Spec coverage:**
- Three `SectionCard`s (Bảng mã / Văn bản nguồn / Kết quả) → Task 1 Step 1. ✅
- Từ/Sang pickers + swap button + Kiểu chữ + Loại bỏ dấu (ToggleRow) → "Bảng mã" card. ✅
- Source TextEditor + read-only result TextEditor + "Sao chép kết quả" → Văn bản nguồn / Kết quả cards. ✅
- Live conversion (computed `output`, no manual button) → `output` property + `.constant(output)`. ✅
- AppStorage keys preserved verbatim → `@AppStorage` declarations unchanged. ✅
- Theme-only colors; ConvertTool/CodeTable/engine/model untouched → Global Constraints; only ConvertView in the task. ✅
- 149 tests stay green (no new logic → no new test) → Task 1 Step 3. ✅

**2. Placeholder scan:** No TBD/TODO; full code in the code step; command has expected output. ✅

**3. Type consistency:** `ConvertTool.convert(_:from:to:caseMode:removeMark:)` called with the exact labels/types from the current file. `CodeTable(rawValue:)`/`CaseMode(rawValue:)` are `Int`-raw inits matching `@AppStorage` Int defaults. `SectionCard(title:content:)` / `ToggleRow(title:isOn:)` signatures match their call sites. `.scrollContentBackground(.hidden)` is macOS 13.3+ (target is 14.0). ✅
