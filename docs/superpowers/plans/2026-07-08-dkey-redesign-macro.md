# Screen ④ Gõ tắt (macro tab) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Gõ tắt (macro) settings tab into the mockup's card style (screen 1c) using the `SectionCard`/`ToggleRow` primitives, add a search filter, and keep all existing macro functionality.

**Architecture:** A pure helper `MacroFilter.filter(_:query:)` does case-insensitive substring filtering on key/content. `MacroView` is rewritten to two `SectionCard`s — a "Tùy chọn gõ tắt" card (the three existing toggles via reusable `ToggleRow`) and a "Gõ tắt" card (search toolbar + Import/Export + the macro `Table` over the filtered list + add/edit/delete row). No engine, `AppState`, or model changes; every write still targets the full `state.macros`.

**Tech Stack:** SwiftUI + AppKit, macOS 14.0, Swift 5.9, XcodeGen, XCTest.

## Global Constraints

- **Engine untouched.** No file under `Sources/Engine` or `Sources/Platform`. No `AppState`/`DkeySettings`/`MacroStore`/`Macro` change. `SettingsComponents.swift`, `Theme.swift`, `SettingsRootView.swift` NOT modified.
- **Reuse existing primitives & Theme:** `SectionCard(title:content:)` and `ToggleRow(title:subtitle:isOn:enabled:)` from `Sources/App/Views/SettingsComponents.swift`; colors `Color.dkWindowBg / dkPanel / dkText / dkSecondary / dkAccent`. Do NOT redefine them.
- **Run `xcodegen generate` after adding ANY new source/test file** (regenerates the gitignored `dkey.xcodeproj`); else the file is absent from the target and tests crash-loop.
- **Search filters display only.** Add/Edit/Delete/Import must operate on the full `state.macros`, never the filtered subset.
- **Preserve all existing behavior:** the three toggles + their disable-when-off semantics, the selection→editor loading, `MacrosDocument`, `.fileImporter`/`.fileExporter` merge/write logic, `addOrEdit`/`deleteSelected`/`existsKey`.
- **Verbatim UI copy:** card titles `"Tùy chọn gõ tắt"`, `"Gõ tắt"`; toggles `"Bật gõ tắt"`, `"Dùng gõ tắt cả trong chế độ tiếng Anh"`, `"Tự hoa theo từ gốc"` (subtitle `"btw→by the way, Btw→By the way"`); search placeholder `"Tìm gõ tắt…"` (U+2026 ellipsis); buttons `"Nhập…"`, `"Xuất…"`, `"Thêm"`/`"Sửa"`, `"Xoá"`; table columns `"Gõ tắt"`, `"Thay thế bằng"`; editor fields `"Từ tắt"`, `"Nội dung thay thế"`.
- **Existing interfaces (consume, do not change):**
  - `struct Macro: Codable, Equatable, Identifiable { var key: String; var content: String; var id: String { key } }` (Sources/Engine/Macro.swift).
  - `AppState.macros: [Macro]` (@Published; setter persists + updates engine), `AppState.useMacro/useMacroInEnglishMode/autoCapsMacro: Bool` (@Published).
  - `MacroStore().importMacros(from: URL) -> [Macro]`.
- **Test/build command** (repo root): `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`. If a build shows entitlements "modified during build" or stale-file errors, `rm -rf build` (DerivedData) and retry.

---

### Task 1: `MacroFilter.filter` pure helper

Pure, testable case-insensitive filter. No SwiftUI.

**Files:**
- Create: `Sources/App/MacroFilter.swift`
- Test: `Tests/AppTests/MacroFilterTests.swift`

**Interfaces:**
- Consumes: `Macro` (`.key`, `.content`) from `Sources/Engine/Macro.swift`.
- Produces: `enum MacroFilter { static func filter(_ macros: [Macro], query: String) -> [Macro] }` — trims the query; empty/whitespace → returns the input unchanged (original order); otherwise keeps macros whose lowercased `key` OR lowercased `content` contains the lowercased trimmed query. `MacroView` (Task 2) renders the result.

- [ ] **Step 1: Write the failing test**

Create `Tests/AppTests/MacroFilterTests.swift`:

```swift
import XCTest
@testable import dkey

final class MacroFilterTests: XCTestCase {
    private let sample = [
        Macro(key: "vn", content: "Việt Nam"),
        Macro(key: "kg", content: "Kính gửi Anh/Chị,"),
        Macro(key: "dc", content: "được"),
    ]

    func testEmptyOrWhitespaceQueryReturnsAll() {
        XCTAssertEqual(MacroFilter.filter(sample, query: ""), sample)
        XCTAssertEqual(MacroFilter.filter(sample, query: "   "), sample)
    }

    func testMatchByKeyCaseInsensitive() {
        XCTAssertEqual(MacroFilter.filter(sample, query: "VN").map(\.key), ["vn"])
    }

    func testMatchByContentCaseInsensitive() {
        XCTAssertEqual(MacroFilter.filter(sample, query: "gửi").map(\.key), ["kg"])
    }

    func testNoMatchReturnsEmpty() {
        XCTAssertTrue(MacroFilter.filter(sample, query: "zzz").isEmpty)
    }

    func testPreservesOriginalOrder() {
        XCTAssertEqual(MacroFilter.filter(sample, query: "").map(\.key), ["vn", "kg", "dc"])
    }
}
```

- [ ] **Step 2: Regenerate the project so the new test file is in the target**

Run: `xcodegen generate`
Expected: `Created project at .../dkey.xcodeproj`

- [ ] **Step 3: Run the test to verify it fails**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: BUILD FAILED — `cannot find 'MacroFilter' in scope`.

- [ ] **Step 4: Write the minimal implementation**

Create `Sources/App/MacroFilter.swift`:

```swift
/// Pure filter for the Gõ tắt (macro) tab search box.
enum MacroFilter {
    /// Case-insensitive substring match on `key` OR `content`. An empty or
    /// whitespace-only query returns all macros in their original order.
    static func filter(_ macros: [Macro], query: String) -> [Macro] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return macros }
        return macros.filter { $0.key.lowercased().contains(q) || $0.content.lowercased().contains(q) }
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **` — 148 tests (143 existing + 5 new), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/MacroFilter.swift Tests/AppTests/MacroFilterTests.swift project.yml
git commit -m "feat(app): MacroFilter.filter pure helper for Gõ tắt search"
```

---

### Task 2: Rewrite `MacroView` into the card style with search

Restyle the tab to two `SectionCard`s and wire the search filter. SwiftUI view rewrite — verified by a clean build and the full suite staying green (visual behaviour deferred to manual smoke).

**Files:**
- Modify (rewrite): `Sources/App/Views/MacroView.swift`

**Interfaces:**
- Consumes: `MacroFilter.filter(_:query:)` (Task 1); `SectionCard`, `ToggleRow` (SettingsComponents.swift); `Color.dk*`; `AppState.macros/useMacro/useMacroInEnglishMode/autoCapsMacro`; `Macro`; `MacroStore().importMacros(from:)`.
- Produces: rewritten `struct MacroView: View` (still hosted by `SettingsRootView` `.macro` case) and the unchanged `struct MacrosDocument: FileDocument`.

- [ ] **Step 1: Rewrite the view**

Replace the entire contents of `Sources/App/Views/MacroView.swift` with:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct MacroView: View {
    @EnvironmentObject private var state: AppState
    @State private var searchQuery = ""
    @State private var selection: Macro.ID?
    @State private var keyField = ""
    @State private var contentField = ""
    @State private var importing = false
    @State private var exporting = false

    private var filteredMacros: [Macro] { MacroFilter.filter(state.macros, query: searchQuery) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: "Tùy chọn gõ tắt") {
                    VStack(alignment: .leading, spacing: 10) {
                        ToggleRow(title: "Bật gõ tắt", isOn: $state.useMacro)
                        ToggleRow(title: "Dùng gõ tắt cả trong chế độ tiếng Anh",
                                  isOn: $state.useMacroInEnglishMode,
                                  enabled: state.useMacro)
                        ToggleRow(title: "Tự hoa theo từ gốc",
                                  subtitle: "btw→by the way, Btw→By the way",
                                  isOn: $state.autoCapsMacro,
                                  enabled: state.useMacro)
                    }
                }

                SectionCard(title: "Gõ tắt") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Color.dkSecondary)
                                TextField("Tìm gõ tắt…", text: $searchQuery)
                                    .textFieldStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.dkWindowBg, in: RoundedRectangle(cornerRadius: 7))
                            Spacer()
                            Button("Nhập…") { importing = true }
                            Button("Xuất…") { exporting = true }
                        }

                        Table(filteredMacros, selection: $selection) {
                            TableColumn("Gõ tắt", value: \.key)
                            TableColumn("Thay thế bằng", value: \.content)
                        }
                        .frame(minHeight: 200)
                        .onChange(of: selection) { _, id in
                            if let m = state.macros.first(where: { $0.id == id }) {
                                keyField = m.key; contentField = m.content
                            } else {
                                keyField = ""; contentField = ""
                            }
                        }

                        HStack {
                            TextField("Từ tắt", text: $keyField).frame(width: 120)
                            TextField("Nội dung thay thế", text: $contentField)
                            Button(existsKey ? "Sửa" : "Thêm") { addOrEdit() }
                                .disabled(keyField.isEmpty)
                            Button("Xoá", role: .destructive) { deleteSelected() }
                                .disabled(selection == nil)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dkWindowBg)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { result in
            if case .success(let url) = result {
                let imported = MacroStore().importMacros(from: url)
                var merged = state.macros
                for m in imported {
                    if let i = merged.firstIndex(where: { $0.key == m.key }) { merged[i] = m }
                    else { merged.append(m) }
                }
                state.macros = merged
            }
        }
        .fileExporter(isPresented: $exporting, document: MacrosDocument(state.macros),
                      contentType: .json, defaultFilename: "macros") { _ in }
    }

    private var existsKey: Bool { state.macros.contains { $0.key == keyField } }

    private func addOrEdit() {
        var m = state.macros
        if let i = m.firstIndex(where: { $0.key == keyField }) { m[i].content = contentField }
        else { m.append(Macro(key: keyField, content: contentField)) }
        state.macros = m; keyField = ""; contentField = ""
    }

    private func deleteSelected() {
        state.macros.removeAll { $0.id == selection }
        selection = nil; keyField = ""; contentField = ""
    }
}

/// FileDocument for exporting macros as JSON.
struct MacrosDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let macros: [Macro]
    init(_ macros: [Macro]) { self.macros = macros }
    init(configuration: ReadConfiguration) throws { macros = [] }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: (try? JSONEncoder().encode(macros)) ?? Data())
    }
}
```

- [ ] **Step 2: Regenerate the project (no new file, but keep the flow consistent)**

Run: `xcodegen generate`
Expected: `Created project at .../dkey.xcodeproj` (no target change — MacroView.swift already in the target; safe to run.)

- [ ] **Step 3: Build + run the full suite**

Run: `xcodebuild -scheme dkey -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **`, 148 tests, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/Views/MacroView.swift
git commit -m "feat(app): redesign Gõ tắt tab with cards + search filter (screen ④)"
```

---

## Manual smoke (deferred to user)

Open Settings → Gõ tắt tab:
1. Two cards render in the warm `#faf9f5` background.
2. "Bật gõ tắt" toggles macro on/off; the two sub-toggles dim + go inert when it is off.
3. Typing in the search box filters the table by key OR content, case-insensitively; clearing it shows all rows again.
4. Selecting a row loads it into the editor; "Thêm"/"Sửa"/"Xoá" and "Nhập…"/"Xuất…" all still work — and adding while a filter is active still adds to the full list.

---

## Self-Review

**1. Spec coverage:**
- Pure `MacroFilter.filter` (empty/trim/case-insensitive key|content) → Task 1. ✅
- "Tùy chọn gõ tắt" card with 3 toggles via `ToggleRow` (sub-toggles `enabled: state.useMacro`) → Task 2 Step 1. ✅
- "Gõ tắt" card: search toolbar + Nhập/Xuất + `Table` (Gõ tắt/Thay thế bằng) over filtered list + add/edit/delete row → Task 2 Step 1. ✅
- Writes target full `state.macros` (addOrEdit/deleteSelected/import unchanged) → Task 2 Step 1. ✅
- Existing behavior preserved (selection→editor, MacrosDocument, importer/exporter) → Task 2 Step 1. ✅
- Theme-only colors; SettingsComponents/Theme/engine/model untouched → Global Constraints; only MacroView + new MacroFilter in the tasks. ✅
- 143 existing tests stay green + 5 new → Task 1 Step 5, Task 2 Step 3 (148). ✅

**2. Placeholder scan:** No TBD/TODO; full code in every code step; commands have expected output. ✅

**3. Type consistency:** `MacroFilter.filter(_ macros: [Macro], query: String) -> [Macro]` defined in Task 1, called identically in Task 2 (`MacroFilter.filter(state.macros, query: searchQuery)`). `Macro.id == key` (String) matches `selection: Macro.ID?`. `SectionCard(title:content:)` / `ToggleRow(title:subtitle:isOn:enabled:)` signatures match their call sites. `addOrEdit`/`deleteSelected`/`existsKey`/`MacrosDocument` carried over verbatim from the current file. ✅
