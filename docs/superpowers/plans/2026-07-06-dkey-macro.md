# Gõ tắt (Macro) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A text-expansion macro feature — define `key → content` shortcuts that expand at a word-break — with English-mode, auto-caps, JSON persistence + import/export, and an editor tab.

**Architecture:** A pure `MacroTable` does lookup + auto-caps; a controller-layer `MacroExpander` tracks the displayed word and expands on a word-break; `InputController` wires it in above the VN/EN decision (the `TelexEngine` stays macro-free). A `MacroStore` persists to JSON; `MacroView` edits it.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit (macOS 14), XCTest, XcodeGen.

## Global Constraints

- `TelexEngine` and `Sources/Engine/` diacritic logic are NOT modified — macro lives in the controller/platform + app layers. `MacroTable`/`Macro` may live in `Sources/Engine/` but are pure (no AppKit).
- Matching is on the **displayed** word (post-transform), reproducing OpenKey `Macro.cpp:findMacro`. Auto-caps rules: trigger all-lowercase → content as-is; first char upper (rest not) → capitalize content's first char; first AND second char upper → uppercase whole content (`btw→by the way`, `Btw→By the way`, `BTW→BY THE WAY`).
- Macro expansion runs when `useMacro` is on AND (Vietnamese is on OR `useMacroInEnglishMode` is on).
- Persistence: macros in `~/Library/Application Support/dkey/macros.json` (array of `{key, content}`); the 3 toggles (`useMacro`, `useMacroInEnglishMode`, `autoCapsMacro`) in `DkeySettings`.
- No regression: all prior tests (97 on `main`) stay green; Telex/VNI parity unchanged (engine untouched).
- XcodeGen: run `xcodegen generate` after adding any new source/test file. `dkey.xcodeproj` gitignored — never commit it.
- Deployment macOS 14.0, Swift 5.9. Work on `feature/macro` (already created), commit after each task.

---

## File Structure

- `Sources/Engine/Macro.swift` *(new)* — `struct Macro` value type.
- `Sources/Engine/MacroTable.swift` *(new)* — pure lookup + auto-caps.
- `Sources/Platform/MacroExpander.swift` *(new)* — displayed-word tracking + break-time expansion.
- `Sources/Platform/InputController.swift` *(modify)* — wire the expander into `handle`.
- `Sources/App/MacroStore.swift` *(new)* — JSON persistence + import/export.
- `Sources/App/DkeySettings.swift` *(modify)* — 3 macro toggles.
- `Sources/App/AppState.swift` *(modify)* — publish macros + toggles; apply to controller.
- `Sources/App/Views/MacroView.swift` *(new)* — editor tab.
- `Sources/App/Views/SettingsRootView.swift` *(modify)* — route `.macro`.
- `Tests/MacroTests/*` *(new)*; `project.yml` *(modify)* — add `Tests/MacroTests`.

---

## Task 1: Macro model + MacroTable (pure lookup + auto-caps)

**Files:**
- Create: `Sources/Engine/Macro.swift`, `Sources/Engine/MacroTable.swift`
- Create: `Tests/MacroTests/MacroTableTests.swift`
- Modify: `project.yml` (add `Tests/MacroTests`)

**Interfaces:**
- Produces: `struct Macro: Codable, Equatable, Identifiable { var id: String { key }; var key: String; var content: String }`.
- Produces: `struct MacroTable { init(_ macros: [Macro]); func expansion(for word: String, autoCaps: Bool) -> String? }`.

- [ ] **Step 1: Add the test dir to project.yml**

In `project.yml` under `dkeyTests: sources:`, add `- path: Tests/MacroTests`. Then `xcodegen generate`.

- [ ] **Step 2: Write the failing tests**

Create `Tests/MacroTests/MacroTableTests.swift`:

```swift
import XCTest
@testable import dkey

final class MacroTableTests: XCTestCase {
    private let table = MacroTable([
        Macro(key: "vn", content: "Việt Nam"),
        Macro(key: "btw", content: "by the way"),
    ])

    func testExactMatch() {
        XCTAssertEqual(table.expansion(for: "vn", autoCaps: false), "Việt Nam")
        XCTAssertEqual(table.expansion(for: "btw", autoCaps: false), "by the way")
    }

    func testNoMatch() {
        XCTAssertNil(table.expansion(for: "xyz", autoCaps: false))
        XCTAssertNil(table.expansion(for: "VN", autoCaps: false)) // no auto-caps → exact only
    }

    func testAutoCapsFirst() {
        XCTAssertEqual(table.expansion(for: "Btw", autoCaps: true), "By the way")
    }

    func testAutoCapsAll() {
        XCTAssertEqual(table.expansion(for: "BTW", autoCaps: true), "BY THE WAY")
    }

    func testAutoCapsLowerStillExact() {
        XCTAssertEqual(table.expansion(for: "btw", autoCaps: true), "by the way")
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `cd /Users/dat.nguyenmanh/Desktop/dat/my-git/dkey && xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: compile failure — `Macro` / `MacroTable` undefined.

- [ ] **Step 4: Implement**

Create `Sources/Engine/Macro.swift`:

```swift
import Foundation

/// One text-expansion shortcut: type `key`, get `content`.
public struct Macro: Codable, Equatable, Identifiable {
    public var key: String
    public var content: String
    public var id: String { key }
    public init(key: String, content: String) { self.key = key; self.content = content }
}
```

Create `Sources/Engine/MacroTable.swift`:

```swift
import Foundation

/// Pure macro lookup with optional auto-capitalisation (port of Macro.cpp:findMacro semantics).
public struct MacroTable {
    private let byKey: [String: String]

    public init(_ macros: [Macro]) {
        var m: [String: String] = [:]
        for macro in macros where !macro.key.isEmpty { m[macro.key] = macro.content }
        byKey = m
    }

    /// Returns the expansion for `word`, or nil. With `autoCaps`, an all-lower stored key can
    /// still match a Cased trigger, casing the content to mirror the trigger.
    public func expansion(for word: String, autoCaps: Bool) -> String? {
        if let exact = byKey[word] { return exact }
        guard autoCaps, !word.isEmpty else { return nil }
        let lowerKey = word.lowercased()
        guard lowerKey != word, let content = byKey[lowerKey] else { return nil }

        let chars = Array(word)
        let firstUpper = chars[0].isUppercase
        let secondUpper = chars.count > 1 && chars[1].isUppercase
        if firstUpper && secondUpper { return content.uppercased() }
        if firstUpper { return content.prefix(1).uppercased() + content.dropFirst() }
        return content
    }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: `TEST SUCCEEDED` — MacroTableTests pass, prior tests green.

- [ ] **Step 6: Commit**

```bash
git add project.yml Sources/Engine/Macro.swift Sources/Engine/MacroTable.swift Tests/MacroTests/MacroTableTests.swift
git commit -m "feat(engine): Macro model + MacroTable lookup with auto-caps"
```

---

## Task 2: MacroExpander (displayed-word tracking + break expansion)

**Files:**
- Create: `Sources/Platform/MacroExpander.swift`
- Create: `Tests/MacroTests/MacroExpanderTests.swift`

**Interfaces:**
- Consumes: `MacroTable`, `Macro`.
- Produces: `final class MacroExpander` with:
  - `var isEnabled: Bool`, `var autoCaps: Bool`, `func setMacros(_ macros: [Macro])`
  - `func apply(backspaces: Int, chars: [Unicode.Scalar])` — update the tracked word
  - `func expand() -> (backspaces: Int, content: [Unicode.Scalar])?` — look up the current word; nil if disabled/no match
  - `func reset()`
  The caller resets after `expand()` and appends the break scalar itself.

- [ ] **Step 1: Write the failing tests**

Create `Tests/MacroTests/MacroExpanderTests.swift`:

```swift
import XCTest
@testable import dkey

final class MacroExpanderTests: XCTestCase {
    private func expander() -> MacroExpander {
        let e = MacroExpander()
        e.isEnabled = true
        e.setMacros([Macro(key: "vn", content: "Việt Nam"), Macro(key: "btw", content: "by the way")])
        return e
    }

    private func type(_ s: String, into e: MacroExpander) {
        for ch in s { e.apply(backspaces: 0, chars: Array(String(ch).unicodeScalars)) }
    }

    func testExpandsOnMatch() {
        let e = expander(); type("vn", into: e)
        let hit = e.expand()
        XCTAssertEqual(hit?.backspaces, 2)
        XCTAssertEqual(String(String.UnicodeScalarView(hit?.content ?? [])), "Việt Nam")
    }

    func testNoMatchReturnsNil() {
        let e = expander(); type("xyz", into: e)
        XCTAssertNil(e.expand())
    }

    func testDisabledReturnsNil() {
        let e = expander(); e.isEnabled = false; type("vn", into: e)
        XCTAssertNil(e.expand())
    }

    func testAutoCaps() {
        let e = expander(); e.autoCaps = true; type("Btw", into: e)
        XCTAssertEqual(String(String.UnicodeScalarView(e.expand()?.content ?? [])), "By the way")
    }

    func testResetClearsWord() {
        let e = expander(); type("vn", into: e); e.reset()
        XCTAssertNil(e.expand())
    }

    func testBackspacePops() {
        let e = expander(); type("vno", into: e)
        e.apply(backspaces: 1, chars: [])   // delete the 'o'
        let hit = e.expand()
        XCTAssertEqual(hit?.backspaces, 2)
        XCTAssertEqual(String(String.UnicodeScalarView(hit?.content ?? [])), "Việt Nam")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: compile failure — `MacroExpander` undefined.

- [ ] **Step 3: Implement**

Create `Sources/Platform/MacroExpander.swift`:

```swift
import Foundation

/// Tracks the currently-typed (displayed) word and expands it into macro content at a word break.
/// Pure logic — no CGEvent. Lives in InputController; fed the display delta of each key.
public final class MacroExpander {
    public var isEnabled = false
    public var autoCaps = false
    private var table = MacroTable([])
    private var word: [Character] = []

    public init() {}

    public func setMacros(_ macros: [Macro]) { table = MacroTable(macros) }

    /// Apply a key's display effect to the tracked word: delete `backspaces`, then append `chars`.
    public func apply(backspaces: Int, chars: [Unicode.Scalar]) {
        for _ in 0..<backspaces where !word.isEmpty { word.removeLast() }
        word.append(contentsOf: String(String.UnicodeScalarView(chars)))
    }

    /// If the tracked word is a macro, return (# chars to delete, expansion scalars). Caller resets after.
    public func expand() -> (backspaces: Int, content: [Unicode.Scalar])? {
        guard isEnabled, !word.isEmpty else { return nil }
        guard let content = table.expansion(for: String(word), autoCaps: autoCaps) else { return nil }
        return (word.count, Array(content.unicodeScalars))
    }

    public func reset() { word.removeAll(keepingCapacity: true) }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Platform/MacroExpander.swift Tests/MacroTests/MacroExpanderTests.swift
git commit -m "feat(platform): MacroExpander word tracking + break expansion"
```

---

## Task 3: Wire MacroExpander into InputController

**Files:**
- Modify: `Sources/Platform/InputController.swift`
- Create: `Tests/MacroTests/InputControllerMacroTests.swift`

**Interfaces:**
- Consumes: `MacroExpander`, `SynthesisPlan`, `KeyEvent`, `TelexEngine.breakCodes`, `keyCodeToCharacter(_:)`, `EngineMask`.
- Produces: `InputController.macro: MacroExpander` (public), `InputController.useMacroInEnglishMode: Bool`.

- [ ] **Step 1: Write the failing integration tests**

Create `Tests/MacroTests/InputControllerMacroTests.swift`:

```swift
import XCTest
@testable import dkey

final class InputControllerMacroTests: XCTestCase {
    private func controller(enMode: Bool = false) -> InputController {
        let c = InputController()
        c.macro.isEnabled = true
        c.macro.setMacros([Macro(key: "vn", content: "Việt Nam")])
        c.useMacroInEnglishMode = enMode
        return c
    }
    private func down(_ code: UInt16, caps: Bool = false) -> KeyEvent {
        KeyEvent(keyCode: code, caps: caps, hasOtherControl: false, kind: .keyDown, flags: 0)
    }

    func testExpandsOnSpace() {
        let c = controller()
        _ = c.handle(down(KeyCode.v)); _ = c.handle(down(KeyCode.n))
        let plan = c.handle(down(KeyCode.space))
        XCTAssertEqual(plan, .consume(backspaces: 2, chars: Array("Việt Nam ".unicodeScalars)))
    }

    func testNonMacroWordPassesThrough() {
        let c = controller()
        _ = c.handle(down(KeyCode.x)); _ = c.handle(down(KeyCode.y))
        XCTAssertEqual(c.handle(down(KeyCode.space)), .passthrough)
    }

    func testDisabledMacroNoExpand() {
        let c = controller(); c.macro.isEnabled = false
        _ = c.handle(down(KeyCode.v)); _ = c.handle(down(KeyCode.n))
        XCTAssertEqual(c.handle(down(KeyCode.space)), .passthrough)
    }

    func testEnglishModeExpandsWhenAllowed() {
        let c = controller(enMode: true); c.setVietnamese(false)
        _ = c.handle(down(KeyCode.v)); _ = c.handle(down(KeyCode.n))
        XCTAssertEqual(c.handle(down(KeyCode.space)), .consume(backspaces: 2, chars: Array("Việt Nam ".unicodeScalars)))
    }

    func testEnglishModeNoExpandWhenDisallowed() {
        let c = controller(enMode: false); c.setVietnamese(false)
        _ = c.handle(down(KeyCode.v)); _ = c.handle(down(KeyCode.n))
        XCTAssertEqual(c.handle(down(KeyCode.space)), .passthrough)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: compile failure — `InputController.macro` / `useMacroInEnglishMode` undefined.

- [ ] **Step 3: Implement the integration**

Rewrite `Sources/Platform/InputController.swift`'s `handle` (and add the two members). The full file:

```swift
import Foundation

/// Pure decision core: turns a KeyEvent into a SynthesisPlan. No CGEvent here.
public final class InputController {
    public let engine: TelexEngine
    public var isVietnamese: Bool
    public var switchKeyStatus: Int32
    public let macro = MacroExpander()
    public var useMacroInEnglishMode = false
    public var onLanguageChanged: ((Bool) -> Void)?

    public init(engine: TelexEngine = TelexEngine(),
                isVietnamese: Bool = true,
                switchKeyStatus: Int32 = 0x7A000206) {
        self.engine = engine
        self.isVietnamese = isVietnamese
        self.switchKeyStatus = switchKeyStatus
    }

    public func setVietnamese(_ on: Bool) {
        isVietnamese = on
        engine.newSession()
        macro.reset()
    }

    public func apply(inputMethod: InputMethod, modernOrthography: Bool, switchKeyStatus: Int32) {
        engine.inputMethod = inputMethod
        engine.useModernOrthography = modernOrthography
        self.switchKeyStatus = switchKeyStatus
        engine.newSession()
        macro.reset()
    }

    /// True while macro expansion is permitted for the current language state.
    private var macroActive: Bool { macro.isEnabled && (isVietnamese || useMacroInEnglishMode) }

    public func handle(_ e: KeyEvent) -> SynthesisPlan {
        switch e.kind {
        case .flagsChanged, .keyUp: return .passthrough
        case .keyDown: break
        }
        // 1. Hotkey.
        if HotkeyMatcher.matches(status: switchKeyStatus, keyCode: e.keyCode, flags: e.flags) {
            isVietnamese.toggle(); engine.newSession(); macro.reset()
            onLanguageChanged?(isVietnamese)
            return .toggleLanguage
        }
        // 2. Control/command shortcut → break the word, pass through.
        if e.hasOtherControl { engine.newSession(); macro.reset(); return .passthrough }

        // 3. Backspace (only intercepted when macro is active — otherwise behaviour is 100%
        //    unchanged). Keep the macro word in sync and pass through. We deliberately do NOT wire
        //    engine.backspace() (it has no callers today; adding backspace re-placement is out of
        //    scope for this feature). When macro is off, Delete falls through to the existing path.
        if macroActive && e.keyCode == KeyCode.delete {
            macro.apply(backspaces: 1, chars: [])
            return .passthrough
        }

        // 4. Word-break key: try macro expansion first.
        if TelexEngine.breakCodes.contains(e.keyCode) {
            if macroActive, let (bs, content) = macro.expand(), let brk = Self.breakScalar(for: e.keyCode) {
                macro.reset(); engine.newSession()
                return .consume(backspaces: bs, chars: content + [brk])
            }
            macro.reset()
            if isVietnamese { engine.newSession() }
            return .passthrough
        }

        // 5. Normal key.
        if !isVietnamese {
            // English mode: track the literal char for macro; pass the key through.
            if macroActive, let scalar = Self.literalScalar(keyCode: e.keyCode, caps: e.caps) {
                macro.apply(backspaces: 0, chars: [scalar])
            }
            return .passthrough
        }
        let out = engine.handle(key: e.keyCode, caps: e.caps)
        if macroActive { macro.apply(backspaces: out.backspaceCount, chars: out.newChars) }
        switch out.action {
        case .passthrough, .wordBreak: return .passthrough
        case .process, .restore: return .consume(backspaces: out.backspaceCount, chars: out.newChars)
        }
    }

    /// The scalar a printable break key inserts (space/enter/tab + punctuation), else nil.
    static func breakScalar(for keyCode: UInt16) -> Unicode.Scalar? {
        switch keyCode {
        case KeyCode.space: return " "
        case KeyCode.enter, KeyCode.ret: return "\n"
        case KeyCode.tab: return "\t"
        default: return literalScalar(keyCode: keyCode, caps: false)
        }
    }

    /// ASCII scalar for a keyCode (letters/digits/basic punctuation via keyCodeToCharacter), else nil.
    static func literalScalar(keyCode: UInt16, caps: Bool) -> Unicode.Scalar? {
        let cell = UInt32(keyCode) | (caps ? EngineMask.caps : 0)
        let ascii = keyCodeToCharacter(cell)
        return ascii != 0 ? Unicode.Scalar(ascii) : nil
    }
}
```

Notes for the implementer:
- `keyCodeToCharacter` (in `VietnameseTables.swift`) maps a cell (keycode|caps) → ASCII `UInt16`, returning 0 for unmapped keys. Its `asciiTable` covers `a–z A–Z 0–9 [ ] space . ,` — enough for common triggers; arrow/esc/other breaks correctly reset without expanding (`breakScalar` returns nil for them → falls through to the reset+passthrough path).
- Do NOT feed the macro word for the plain-insert case unless `macroActive` (avoids wasted work and keeps VN-off behaviour unchanged when macro is off).

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: `TEST SUCCEEDED` — the 5 InputControllerMacroTests pass and ALL prior tests (incl. `PlatformTests/InputControllerTests`) stay green (macro is off by default there, so behaviour is unchanged).

- [ ] **Step 5: Commit**

```bash
git add Sources/Platform/InputController.swift Tests/MacroTests/InputControllerMacroTests.swift
git commit -m "feat(platform): wire MacroExpander into InputController"
```

---

## Task 4: MacroStore persistence + import/export

**Files:**
- Create: `Sources/App/MacroStore.swift`
- Create: `Tests/MacroTests/MacroStoreTests.swift`

**Interfaces:**
- Consumes: `Macro`.
- Produces: `struct MacroStore { init(directory: URL); func load() -> [Macro]; func save(_ macros: [Macro]); func importMacros(from url: URL) -> [Macro]; func export(_ macros: [Macro], to url: URL) throws }`. Default directory = `~/Library/Application Support/dkey/`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/MacroTests/MacroStoreTests.swift`:

```swift
import XCTest
@testable import dkey

final class MacroStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func testLoadEmptyWhenMissing() {
        XCTAssertEqual(MacroStore(directory: tempDir()).load(), [])
    }

    func testRoundTrip() {
        let store = MacroStore(directory: tempDir())
        let macros = [Macro(key: "vn", content: "Việt Nam"), Macro(key: "hn", content: "Hà Nội")]
        store.save(macros)
        XCTAssertEqual(store.load(), macros)
    }

    func testCorruptFileLoadsEmpty() {
        let dir = tempDir()
        try? "not json".data(using: .utf8)!.write(to: dir.appendingPathComponent("macros.json"))
        XCTAssertEqual(MacroStore(directory: dir).load(), [])
    }

    func testExportImportJSON() throws {
        let store = MacroStore(directory: tempDir())
        let macros = [Macro(key: "vn", content: "Việt Nam")]
        let file = tempDir().appendingPathComponent("export.json")
        try store.export(macros, to: file)
        XCTAssertEqual(store.importMacros(from: file), macros)
    }

    func testImportTSV() throws {
        let file = tempDir().appendingPathComponent("in.txt")
        try "vn\tViệt Nam\nhn\tHà Nội\n".data(using: .utf8)!.write(to: file)
        XCTAssertEqual(MacroStore(directory: tempDir()).importMacros(from: file),
                       [Macro(key: "vn", content: "Việt Nam"), Macro(key: "hn", content: "Hà Nội")])
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: compile failure — `MacroStore` undefined.

- [ ] **Step 3: Implement**

Create `Sources/App/MacroStore.swift`:

```swift
import Foundation

/// Persists macros to a JSON file; imports JSON or TSV (`key<TAB>content` per line).
struct MacroStore {
    private let fileURL: URL

    init(directory: URL = MacroStore.defaultDirectory) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("macros.json")
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dkey", isDirectory: true)
    }

    func load() -> [Macro] { decode(fileURL) }

    func save(_ macros: [Macro]) {
        guard let data = try? JSONEncoder().encode(macros) else { return }
        try? data.write(to: fileURL)
    }

    func export(_ macros: [Macro], to url: URL) throws {
        try JSONEncoder().encode(macros).write(to: url)
    }

    /// Import JSON (array of Macro) or, failing that, TSV lines `key<TAB>content`.
    func importMacros(from url: URL) -> [Macro] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        if let m = try? JSONDecoder().decode([Macro].self, from: data) { return m }
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2, !parts[0].isEmpty else { return nil }
            return Macro(key: parts[0], content: parts[1])
        }
    }

    private func decode(_ url: URL) -> [Macro] {
        guard let data = try? Data(contentsOf: url),
              let m = try? JSONDecoder().decode([Macro].self, from: data) else { return [] }
        return m
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Sources/App/MacroStore.swift Tests/MacroTests/MacroStoreTests.swift
git commit -m "feat(app): MacroStore JSON persistence + import/export"
```

---

## Task 5: Settings toggles + AppState wiring

**Files:**
- Modify: `Sources/App/DkeySettings.swift`, `Sources/App/AppState.swift`
- Modify: `Tests/AppTests/SettingsStoreTests.swift` (extend the existing round-trip test)

**Interfaces:**
- Consumes: `MacroStore`, `MacroExpander` (via `controller.macro`), `Macro`.
- Produces: `DkeySettings.useMacro/useMacroInEnglishMode/autoCapsMacro`; `AppState.macros: [Macro]`, `AppState.useMacro/useMacroInEnglishMode/autoCapsMacro`.

- [ ] **Step 1: Extend DkeySettings**

In `Sources/App/DkeySettings.swift`, add three `Bool` fields (default `false`) and update `defaults`:

```swift
    var useMacro: Bool
    var useMacroInEnglishMode: Bool
    var autoCapsMacro: Bool
```
`defaults` gains `useMacro: false, useMacroInEnglishMode: false, autoCapsMacro: false`.

Update the existing `SettingsStoreTests.testRoundTrip` to set these three to `true` and assert they survive.

- [ ] **Step 2: Wire AppState**

In `Sources/App/AppState.swift`:
- Add `private let macroStore = MacroStore()`.
- Add `@Published var macros: [Macro] = []` with `didSet { if !_isReflecting { controller.macro.setMacros(macros); macroStore.save(macros) } }`.
- Add `@Published var useMacro / useMacroInEnglishMode / autoCapsMacro: Bool` each with `didSet { if !_isReflecting { applyMacroFlags(); persist() } }`.
- Add:
```swift
    private func applyMacroFlags() {
        controller.macro.isEnabled = useMacro
        controller.macro.autoCaps = autoCapsMacro
        controller.useMacroInEnglishMode = useMacroInEnglishMode
    }
```
- In `init`, after loading settings (under `_isReflecting = true`): set the three flags from `s`, set `macros = macroStore.load()`, then (after `_isReflecting = false`) call `applyMacroFlags()` and `controller.macro.setMacros(macros)`.
- Extend `persist()` to include the three new fields in the `DkeySettings(...)`.

- [ ] **Step 3: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: `TEST SUCCEEDED` — the extended round-trip test passes; all prior green.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/DkeySettings.swift Sources/App/AppState.swift Tests/AppTests/SettingsStoreTests.swift
git commit -m "feat(app): persist macro toggles + macros, apply to controller"
```

---

## Task 6: MacroView + tab wiring

**Files:**
- Create: `Sources/App/Views/MacroView.swift`
- Modify: `Sources/App/Views/SettingsRootView.swift`

**Interfaces:**
- Consumes: `AppState.macros/useMacro/useMacroInEnglishMode/autoCapsMacro`, `Macro`, `MacroStore` (for import/export).

- [ ] **Step 1: Build the view**

Create `Sources/App/Views/MacroView.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct MacroView: View {
    @EnvironmentObject private var state: AppState
    @State private var selection: Macro.ID?
    @State private var keyField = ""
    @State private var contentField = ""
    @State private var importing = false
    @State private var exporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Bật gõ tắt", isOn: $state.useMacro)
            Group {
                Toggle("Dùng gõ tắt cả trong chế độ tiếng Anh", isOn: $state.useMacroInEnglishMode)
                Toggle("Tự hoa theo từ gốc (btw→by the way, Btw→By the way)", isOn: $state.autoCapsMacro)
            }
            .disabled(!state.useMacro)
            .padding(.leading, 16)

            Table(state.macros, selection: $selection) {
                TableColumn("Từ tắt", value: \.key)
                TableColumn("Nội dung", value: \.content)
            }
            .frame(minHeight: 160)
            .onChange(of: selection) { _, id in
                if let m = state.macros.first(where: { $0.id == id }) { keyField = m.key; contentField = m.content }
            }

            HStack {
                TextField("Từ tắt", text: $keyField).frame(width: 120)
                TextField("Nội dung thay thế", text: $contentField)
                Button(existsKey ? "Sửa" : "Thêm") { addOrEdit() }.disabled(keyField.isEmpty)
                Button("Xoá", role: .destructive) { deleteSelected() }.disabled(selection == nil)
            }
            HStack {
                Button("Nhập…") { importing = true }
                Button("Xuất…") { exporting = true }
            }
        }
        .padding()
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { result in
            if case .success(let url) = result {
                let imported = MacroStore().importMacros(from: url)
                var merged = state.macros
                for m in imported { if let i = merged.firstIndex(where: { $0.key == m.key }) { merged[i] = m } else { merged.append(m) } }
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

- [ ] **Step 2: Route the `.macro` tab**

In `Sources/App/Views/SettingsRootView.swift`, add to the `switch`: `case .macro: MacroView()` (keep `.typing`/`.about`/`.convert`/`default`).

- [ ] **Step 3: Regenerate + build**

Run: `xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug build 2>&1 | tail -8`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Full test pass (regression gate)**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -8`
Expected: `TEST SUCCEEDED` — all macro + prior tests green.

- [ ] **Step 5: Manual smoke (deferred to user)**

Open Cài đặt → Gõ tắt. Enable "Bật gõ tắt"; add `vn → Việt Nam`; in TextEdit type `vn` + space → `Việt Nam `. Add `btw → by the way`, enable auto-caps, type `Btw ` → `By the way `. Toggle "Dùng trong tiếng Anh", turn VI off (⌥Z), type `vn ` → still expands. Export, edit the file, re-import. Type a normal Vietnamese word (`tiếng`) → not swallowed. Relaunch → macros + toggles persist.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/Views/MacroView.swift Sources/App/Views/SettingsRootView.swift
git commit -m "feat(app): Gõ tắt (macro) editor tab"
```

---

## Self-Review

**1. Spec coverage:**
- Macro table + auto-caps → Task 1. ✅
- Displayed-word tracking + break expansion → Task 2. ✅
- Controller integration (VN + English mode, break scalar) → Task 3. ✅
- JSON persistence + import/export (JSON + TSV) → Task 4. ✅
- 3 toggles in DkeySettings + AppState apply → Task 5. ✅
- Editor UI (table, add/edit/delete, toggles, import/export) + route → Task 6. ✅
- Engine untouched / no regression → every task's test step + Task 3 note. ✅
- English-mode gate (`useMacro && (VI || englishMode)`) → Task 3 `macroActive`. ✅

**2. Placeholder scan:** No TBD/TODO; every code step has complete code. Task 5's AppState edits are described against the existing `_isReflecting`/`persist()` pattern (same as the Kiểu gõ feature) with the exact new members/methods, not vague prose.

**3. Type consistency:** `Macro` (Task 1) is used identically across Tasks 2/4/5/6. `MacroTable` (Task 1) ← `MacroExpander` (Task 2). `MacroExpander` API (`isEnabled`/`autoCaps`/`setMacros`/`apply`/`expand`/`reset`) is used identically in Task 3. `InputController.macro`/`useMacroInEnglishMode` (Task 3) ← AppState (Task 5). `MacroStore` (Task 4) signature matches Tasks 5/6 callers. `keyCodeToCharacter`/`EngineMask.caps`/`TelexEngine.breakCodes`/`KeyCode.*` are pre-existing. ✅
