# Kiểu gõ (Telex + VNI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the "Kiểu gõ" Settings tab into a working feature — add a VNI typing method, let the user pick typing method / tone-placement style / language-switch key, and persist those choices.

**Architecture:** Add an `InputMethod` strategy to the existing `TelexEngine`. VNI is a faithful port of OpenKey's `vInputType==vVNI` path, which is fundamentally a key-remap (`ProcessingChar[vInputType]`, Engine.cpp:35-36) plus a `keyForAEO`/VEI scan (Engine.cpp:1145-1192); every diacritic function it calls (`insertMark`, `insertAOE`, `insertW`, `insertD`, `removeMark`) is already shared. A new `Codable`/`UserDefaults` settings layer backs the UI and every later feature.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit (macOS 14), XCTest, XcodeGen. Reference source (GPL v3): `../mkey/Sources/Engine/`.

## Global Constraints

- `Sources/Engine/` stays **pure Swift** — no `import AppKit`/`SwiftUI`.
- Engine output is **Unicode NFC**, reusing the existing `codeTableUnicode`. No new code tables.
- **No regression:** the existing Telex parity corpus + all 58 current tests must stay green after every task.
- VNI is a **faithful port** from OpenKey `../mkey/Sources/Engine/` (Engine.cpp / DataType.h). The parity corpus (oracle-defined golden) is the correctness authority.
- Defaults: typing method **Telex**, tone style **modern** (`useModernOrthography = true`), switch key **⌥Z** = `0x7A000206`, Vietnamese **on**.
- Deployment target macOS 14.0, `SWIFT_VERSION` 5.9.
- Build/test after a branch checkout: `rm -rf build` first (DerivedData entitlements quirk), then `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug <build|test>`.
- Work on a feature branch, not `main`. Commit after every task.

---

## File Structure

**Engine (pure Swift):**
- `Sources/Engine/InputMethod.swift` *(new)* — `enum InputMethod { case telex, vni }`, `Codable`.
- `Sources/Engine/EngineOutput.swift` *(modify)* — add `var inputMethod` to `protocol InputEngine`.
- `Sources/Engine/TelexEngine.swift` *(modify)* — `inputMethod` property; method-aware key predicates; VNI AOE/W branch.

**Persistence + App:**
- `Sources/App/DkeySettings.swift` *(new)* — `Codable` settings model + defaults.
- `Sources/App/SettingsStore.swift` *(new)* — load/save to `UserDefaults`.
- `Sources/App/AppState.swift` *(modify)* — publish `inputMethod`/`useModernOrthography`; persist + apply on change; load on init.
- `Sources/App/SwitchKeyCodec.swift` *(new)* — pure bitfield encode/validate.
- `Sources/App/KeyRecorderField.swift` *(new)* — `NSViewRepresentable` capturing a shortcut.
- `Sources/App/Views/TypingSettingsView.swift` *(new)* — the tab UI.
- `Sources/App/Views/SettingsRootView.swift` *(modify)* — route `.typing` to `TypingSettingsView`.

**Oracle + tests:**
- `scripts/openkey-oracle/oracle.cpp` *(modify)* — accept input-type arg; map digits for VNI.
- `scripts/gen-parity-corpus-vni.sh` *(new)* — generate `Tests/Fixtures/parity-corpus-vni.json`.
- `Tests/Fixtures/parity-corpus-vni.json` *(new, committed)*.
- `Tests/EngineTests/TelexTestSupport.swift` *(modify)* — add `method:` param to `type()`.
- `Tests/EngineTests/VNITests.swift` *(new)* — curated VNI cases.
- `Tests/ParityTests/ParityTests.swift` *(modify)* — load + assert VNI corpus.
- `Tests/AppTests/SettingsStoreTests.swift` + `SwitchKeyCodecTests.swift` *(new)* — round-trip + codec.

---

## Task 1: InputMethod scaffold + VNI mark / đ / remove keys

Adds the `InputMethod` type and makes the mark keys (`1-5`), `đ` (`9`), and remove-tone (`0`) work in VNI by routing them, through method-aware predicates, into the **existing** shared diacritic functions. The circumflex/horn/breve keys (`6/7/8`) come in Task 2.

**Files:**
- Create: `Sources/Engine/InputMethod.swift`
- Modify: `Sources/Engine/EngineOutput.swift` (protocol), `Sources/Engine/TelexEngine.swift`
- Modify: `Tests/EngineTests/TelexTestSupport.swift`
- Create: `Tests/EngineTests/VNITests.swift`

**Interfaces:**
- Produces: `enum InputMethod: String, Codable, CaseIterable { case telex, vni }`; `TelexEngine.inputMethod: InputMethod` (default `.telex`); `InputEngine.inputMethod` requirement.
- Produces (test helper): `type(_ s: String, modern: Bool = true, method: InputMethod = .telex, engine: TelexEngine? = nil) -> String`.
- Consumes: existing `insertMark(_:)`, `insertD(caps:)`, `removeMark()`, `insertKey(_:caps:)`, `afterMainKey(_:plainInsert:)`, `EngineMask.mark1…mark5`, `KeyCode.n0…n9`.

- [ ] **Step 1: Write the failing VNI mark/đ/remove tests**

Create `Tests/EngineTests/VNITests.swift`:

```swift
import XCTest
@testable import dkey

final class VNITests: XCTestCase {
    private func vni(_ s: String, modern: Bool = true) -> String {
        type(s, modern: modern, method: .vni)
    }

    func testTones() {
        XCTAssertEqual(vni("a1"), "á")
        XCTAssertEqual(vni("a2"), "à")
        XCTAssertEqual(vni("a3"), "ả")
        XCTAssertEqual(vni("a4"), "ã")
        XCTAssertEqual(vni("a5"), "ạ")
    }

    func testDd() {
        XCTAssertEqual(vni("d9"), "đ")
        XCTAssertEqual(vni("d9a2"), "đà")
    }

    func testRemoveTone() {
        XCTAssertEqual(vni("a1"), "á")
        XCTAssertEqual(vni("a10"), "a")   // 0 clears the tone
    }

    func testToneToggleOff() {
        // Re-typing the same tone digit removes it and emits the literal digit.
        XCTAssertEqual(vni("a11"), "a1")
    }

    func testBareDigitIsLiteral() {
        XCTAssertEqual(vni("1"), "1")
        XCTAssertEqual(vni("abc1"), "abc1")
    }

    func testBracketsAreLiteralInVNI() {
        XCTAssertEqual(vni("["), "[")
        XCTAssertEqual(vni("]"), "]")
    }
}
```

- [ ] **Step 2: Add the `method:` param to the shared `type()` helper**

In `Tests/EngineTests/TelexTestSupport.swift`, change the signature and set the method:

```swift
func type(_ telex: String, modern: Bool = true, method: InputMethod = .telex, engine: TelexEngine? = nil) -> String {
    let e = engine ?? TelexEngine()
    e.useModernOrthography = modern
    e.inputMethod = method
    e.newSession()
    // …rest of the body unchanged…
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -20`
Expected: compile failure — `inputMethod` is not a member of `TelexEngine` (and `InputMethod` undefined).

- [ ] **Step 4: Create the `InputMethod` type**

Create `Sources/Engine/InputMethod.swift`:

```swift
import Foundation

/// Typing method. Mirrors OpenKey's vInputType (DataType.h:34-38); we ship the two
/// common ones. VNI drives the same engine core through a different key mapping.
public enum InputMethod: String, Codable, CaseIterable {
    case telex
    case vni
}
```

- [ ] **Step 5: Add `inputMethod` to the protocol and engine**

In `Sources/Engine/EngineOutput.swift`, add to `protocol InputEngine`:

```swift
    var inputMethod: InputMethod { get set }
```

In `Sources/Engine/TelexEngine.swift`, next to `useModernOrthography`:

```swift
    public var inputMethod: InputMethod = .telex
```

- [ ] **Step 6: Make the mark / đ / remove / bracket routing method-aware**

In `TelexEngine.swift`, replace the Telex-only predicates and the hard-coded key checks at the top of `handle` with method-aware helpers. Add these private helpers near the existing `isMarkKey`:

```swift
    // Which physical key plays each role, per input method.
    // Mirrors OpenKey ProcessingChar[vInputType] (Engine.cpp:35-36):
    //   Telex row uses letters; VNI row: 1-5 tones, 6 circumflex, 7/8 horn/breve, 9 đ, 0 remove.
    private func isKeyZ(_ key: UInt16) -> Bool {   // remove-tone key
        inputMethod == .telex ? key == KeyCode.z : key == KeyCode.n0
    }
    private func isKeyD(_ key: UInt16) -> Bool {   // đ key
        inputMethod == .telex ? key == KeyCode.d : key == KeyCode.n9
    }
    private func markMask(for key: UInt16) -> UInt32? {
        switch inputMethod {
        case .telex:
            switch key {
            case KeyCode.s: return EngineMask.mark1
            case KeyCode.f: return EngineMask.mark2
            case KeyCode.r: return EngineMask.mark3
            case KeyCode.x: return EngineMask.mark4
            case KeyCode.j: return EngineMask.mark5
            default: return nil
            }
        case .vni:
            switch key {
            case KeyCode.n1: return EngineMask.mark1
            case KeyCode.n2: return EngineMask.mark2
            case KeyCode.n3: return EngineMask.mark3
            case KeyCode.n4: return EngineMask.mark4
            case KeyCode.n5: return EngineMask.mark5
            default: return nil
            }
        }
    }
```

Change the existing `isMarkKey` body to be method-aware:

```swift
    private func isMarkKey(_ key: UInt16) -> Bool {
        markMask(for: key) != nil
    }
```

In `handle`, update the routing:
- Replace `if key == KeyCode.z {` with `if isKeyZ(key) {`.
- Replace `if key == KeyCode.d {` with `if isKeyD(key) {`.
- Gate the two bracket branches so they only fire for Telex: change `if key == KeyCode.leftBracket {` to `if inputMethod == .telex && key == KeyCode.leftBracket {` and likewise for `KeyCode.rightBracket`.
- In the mark branch, replace the inline `switch key { case KeyCode.s: … }` that computes `markMask` with:

```swift
        if isMarkKey(key) && buffer.index > 0 {
            guard let markMask = markMask(for: key) else {
                return afterMainKey(insertKey(key, caps: caps), plainInsert: true)
            }
            for group in vowelForMark {
                // …unchanged loop body, using `markMask`…
```

Leave the Telex `w` branch (`if key == KeyCode.w`), the double-vowel branch (`if isDoubleKey(key) …`), and `isDoubleKey` itself unchanged — VNI's `6/7/8` are handled in Task 2.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -20`
Expected: `TEST SUCCEEDED` — new `VNITests` (mark/đ/remove/literal/bracket) pass, and all prior tests (58) still pass. `testToneToggleOff` and `testRemoveTone` exercise the shared `insertMark`/`removeMark` restore paths.

- [ ] **Step 8: Commit**

```bash
git add Sources/Engine/InputMethod.swift Sources/Engine/EngineOutput.swift Sources/Engine/TelexEngine.swift Tests/EngineTests/TelexTestSupport.swift Tests/EngineTests/VNITests.swift
git commit -m "feat(engine): add InputMethod + VNI tone/đ/remove routing"
```

---

## Task 2: VNI circumflex / horn / breve (keys 6 / 7 / 8)

Ports OpenKey's `vInputType==vVNI` AOE/W handling (Engine.cpp:1145-1192): `6` = circumflex on the current A/E/O, `7` = horn (ơ/ư), `8` = breve (ă), reusing `insertAOE` / `insertW`.

**Files:**
- Modify: `Sources/Engine/TelexEngine.swift`
- Modify: `Tests/EngineTests/VNITests.swift`

**Interfaces:**
- Consumes: `buffer.index`, `buffer[i].cellKeyCode`, `vowel[UInt16]`, `checkCorrectVowel(patterns:patternIdx:markKey:)`, `insertAOE(_:caps:)`, `insertW(caps:)`, `insertKey(_:caps:)`, `afterMainKey(_:plainInsert:)`, `KeyCode.n6/n7/n8`.
- Produces: `private func handleVNIAOEW(key: UInt16, caps: Bool) -> EngineOutput`.

- [ ] **Step 1: Write the failing circumflex/horn/breve tests**

Append to `VNITests.swift`:

```swift
    func testCircumflex() {
        XCTAssertEqual(vni("a6"), "â")
        XCTAssertEqual(vni("e6"), "ê")
        XCTAssertEqual(vni("o6"), "ô")
        XCTAssertEqual(vni("a6s"), "â")   // stray letter after is separate; core is a6→â
    }

    func testHorn() {
        XCTAssertEqual(vni("o7"), "ơ")
        XCTAssertEqual(vni("u7"), "ư")
    }

    func testBreve() {
        XCTAssertEqual(vni("a8"), "ă")
    }

    func testCircumflexThenTone() {
        XCTAssertEqual(vni("a61"), "ấ")   // â + sắc
        XCTAssertEqual(vni("o62"), "ồ")   // ô + huyền
    }

    func testWord() {
        XCTAssertEqual(vni("vie6t5"), "việt")   // v-i-ê-t + nặng
        XCTAssertEqual(vni("ddo6ng2"), "đồng")  // đ-ô-ng + huyền
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -30`
Expected: the new cases FAIL (`a6` currently yields `a6` — the `6` is inserted literally) while Task 1 cases still pass.

- [ ] **Step 3: Add the VNI AOE/W dispatch**

In `TelexEngine.swift`, near the top of `handle` — **before** the Telex `w`/double branches — intercept VNI `6/7/8`:

```swift
        // VNI circumflex/horn/breve (keys 6/7/8). Telex handles a/e/o + w separately below.
        if inputMethod == .vni && (key == KeyCode.n6 || key == KeyCode.n7 || key == KeyCode.n8) {
            return handleVNIAOEW(key: key, caps: caps)
        }
```

Add the method (port of Engine.cpp:1145-1192):

```swift
    /// VNI 6/7/8 → circumflex/horn/breve. Faithful port of OpenKey vKeyHandleEvent
    /// (Engine.cpp:1145-1192, vInputType==vVNI): scan for the target vowel, compute
    /// keyForAEO, then reuse the shared insertAOE / insertW.
    private func handleVNIAOEW(key: UInt16, caps: Bool) -> EngineOutput {
        // VEI = last O/A/E in the buffer — the circumflex target (Engine.cpp:1145-1152).
        var vei = -1
        for i in stride(from: buffer.index - 1, through: 0, by: -1) {
            let c = buffer[i].cellKeyCode
            if c == KeyCode.o || c == KeyCode.a || c == KeyCode.e { vei = i; break }
        }
        // keyForAEO (Engine.cpp:1154): 7/8 → W; 6 → the vowel at VEI; else the key itself.
        let keyForAEO: UInt16
        if key == KeyCode.n7 || key == KeyCode.n8 {
            keyForAEO = KeyCode.w
        } else if key == KeyCode.n6 {
            keyForAEO = vei >= 0 ? buffer[vei].cellKeyCode : key
        } else {
            keyForAEO = key
        }

        let patterns = vowel[keyForAEO] ?? []
        for l in 0..<patterns.count {
            if buffer.index < patterns[l].count { continue }
            if checkCorrectVowel(patterns: patterns, patternIdx: l, markKey: key) {
                if key == KeyCode.n6 {
                    let out = insertAOE(keyForAEO, caps: caps)
                    if out.action == .restore {
                        let k = insertKey(key, caps: caps)
                        return EngineOutput(backspaceCount: out.backspaceCount,
                                            newChars: out.newChars + k.newChars, action: .restore)
                    }
                    return afterMainKey(out, plainInsert: false)
                } else {
                    // Horn/breve target + guard (Engine.cpp:1170-1179).
                    var vw = -1
                    for j in stride(from: buffer.index - 1, through: 0, by: -1) {
                        let c = buffer[j].cellKeyCode
                        if c == KeyCode.o || c == KeyCode.u || c == KeyCode.a || c == KeyCode.e { vw = j; break }
                    }
                    if vw >= 0 {
                        let cv = buffer[vw].cellKeyCode
                        let prevNotU = vw - 1 >= 0 ? buffer[vw - 1].cellKeyCode != KeyCode.u : true
                        if (key == KeyCode.n7 && cv == KeyCode.a && prevNotU) ||
                           (key == KeyCode.n8 && (cv == KeyCode.o || cv == KeyCode.u)) {
                            break   // blocked → literal digit
                        }
                    }
                    let out = insertW(caps: caps)
                    if out.action == .passthrough { break }
                    if out.action == .restore {
                        let k = insertKey(key, caps: caps)
                        return EngineOutput(backspaceCount: out.backspaceCount,
                                            newChars: out.newChars + k.newChars, action: .restore)
                    }
                    return afterMainKey(out, plainInsert: false)
                }
            }
        }
        // No vowel pattern matched (or guard blocked) → literal digit.
        return afterMainKey(insertKey(key, caps: caps), plainInsert: true)
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -20`
Expected: `TEST SUCCEEDED`. If `testWord` cases differ, treat OpenKey as the authority — Task 3's parity corpus is the systematic check; adjust the port to match, not the expectation.

- [ ] **Step 5: Commit**

```bash
git add Sources/Engine/TelexEngine.swift Tests/EngineTests/VNITests.swift
git commit -m "feat(engine): VNI circumflex/horn/breve (keys 6/7/8)"
```

---

## Task 3: VNI oracle mode + parity corpus

Extends the OpenKey oracle to emit VNI golden output and adds a committed VNI corpus + parity test, matching the existing Telex methodology.

**Files:**
- Modify: `scripts/openkey-oracle/oracle.cpp`
- Create: `scripts/gen-parity-corpus-vni.sh`
- Create: `Tests/Fixtures/parity-corpus-vni.json`
- Modify: `Tests/ParityTests/ParityTests.swift`
- Modify: `project.yml` is **not** needed — `Tests/Fixtures` is already a resources build phase; new JSON is picked up automatically.

**Interfaces:**
- Consumes: `type(_:modern:method:)` from Task 1.
- Produces: `Tests/Fixtures/parity-corpus-vni.json` (array of `{input, modern, classic}` where `input` is a VNI keystroke string).

- [ ] **Step 1: Add an input-type argument to the oracle**

In `scripts/openkey-oracle/oracle.cpp`: read `argv[1]` (`"telex"` default, `"vni"`) and set `vInputType` accordingly before running. In `runOne`, the ASCII→keycode mapping must map `'0'..'9'` to `KEY_0..KEY_9` when VNI (digits are the diacritic keys). Keep the Telex path byte-identical. Concretely, set the global from main:

```cpp
    // near the top of main(), before reading stdin:
    if (argc > 1 && std::string(argv[1]) == "vni") vInputType = 1;   // vVNI
```

and ensure the char loop in `runOne` handles digits (they map through the same keycode table the Swift `KeyCode.keyCode(for:)` uses: `'1'→KEY_1 … '0'→KEY_0`). If the existing mapping already covers digits, no change is needed there; verify by inspection.

- [ ] **Step 2: Write the VNI corpus generator**

Create `scripts/gen-parity-corpus-vni.sh` (mirror `gen-parity-corpus.sh`, but feed **VNI** keystrokes and pass `vni` to the oracle):

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/openkey-oracle/build.sh

INITIALS=( "" b c ch d dd9 g gh h kh l m n ng ngh nh ph qu r s t th tr v x )
VOWELS=( a a6 a8 e e6 i o o6 o7 u u7 oa oe uo u7o7 u7o7i ie6 ye6 )
TONES=( "" 1 2 3 4 5 )
FINALS=( "" c ch m n ng nh p t )

OUT=Tests/Fixtures/parity-corpus-vni.json
{
  for ini in "${INITIALS[@]}"; do
    for v in "${VOWELS[@]}"; do
      for t in "${TONES[@]}"; do
        for fin in "${FINALS[@]}"; do
          printf '%s%s%s%s\n' "$ini" "$v" "$t" "$fin"
        done
      done
    done
  done
} | sort -u | scripts/openkey-oracle/oracle vni | python3 -c '
import sys, json
rows=[]
for line in sys.stdin:
    parts=line.rstrip("\n").split("\t")
    if len(parts)!=3: continue
    rows.append({"input":parts[0],"modern":parts[1],"classic":parts[2]})
json.dump(rows, open("'"$OUT"'","w"), ensure_ascii=False, indent=0)
print(f"wrote {len(rows)} rows to '"$OUT"'")
'
```

Note: `dd9` encodes VNI đ (letters `dd` then `9`); `a6/o7/u7/a8` encode the diacritics. Reverse-map imperfection only lowers coverage — the oracle defines the golden answers.

- [ ] **Step 3: Generate the corpus**

Run: `bash scripts/gen-parity-corpus-vni.sh`
Expected: prints `wrote <N> rows to Tests/Fixtures/parity-corpus-vni.json` (N in the thousands) and the file exists.

- [ ] **Step 4: Add the VNI parity test**

In `Tests/ParityTests/ParityTests.swift`, add a loader + two tests:

```swift
    func loadVNICorpus() throws -> [Row] {
        let url = Bundle(for: ParityTests.self).url(forResource: "parity-corpus-vni", withExtension: "json")!
        return try JSONDecoder().decode([Row].self, from: Data(contentsOf: url))
    }

    func testVNIParityModern() throws {
        var fails: [String] = []
        for row in try loadVNICorpus() {
            let got = type(row.input, modern: true, method: .vni)
            if got != row.modern { fails.append("\(row.input): got \(got) want \(row.modern)") }
        }
        XCTAssertTrue(fails.isEmpty, "VNI modern failures (\(fails.count)):\n" + fails.prefix(40).joined(separator: "\n"))
    }

    func testVNIParityClassic() throws {
        var fails: [String] = []
        for row in try loadVNICorpus() {
            let got = type(row.input, modern: false, method: .vni)
            if got != row.classic { fails.append("\(row.input): got \(got) want \(row.classic)") }
        }
        XCTAssertTrue(fails.isEmpty, "VNI classic failures (\(fails.count)):\n" + fails.prefix(40).joined(separator: "\n"))
    }
```

- [ ] **Step 5: Run the parity tests**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -25`
Expected: `TEST SUCCEEDED`. If VNI parity fails, the failing `input: got X want Y` lines pinpoint port bugs in Task 2 — fix `handleVNIAOEW` (or the Task 1 routing) to match OpenKey, re-run. Telex parity must remain green.

- [ ] **Step 6: Commit**

```bash
git add scripts/openkey-oracle/oracle.cpp scripts/gen-parity-corpus-vni.sh Tests/Fixtures/parity-corpus-vni.json Tests/ParityTests/ParityTests.swift
git commit -m "test(engine): VNI parity corpus from OpenKey oracle"
```

---

## Task 4: Settings persistence layer

A `Codable` snapshot persisted to `UserDefaults`. Foundation for this feature and the three later tabs.

**Files:**
- Create: `Sources/App/DkeySettings.swift`, `Sources/App/SettingsStore.swift`
- Create: `Tests/AppTests/SettingsStoreTests.swift`
- Modify: `project.yml` — add `Tests/AppTests` to `dkeyTests` sources.

**Interfaces:**
- Produces: `struct DkeySettings: Codable, Equatable { var inputMethod: InputMethod; var useModernOrthography: Bool; var switchKeyStatus: Int32; var isVietnamese: Bool }`, `static let defaults`.
- Produces: `struct SettingsStore { init(defaults: UserDefaults = .standard); func load() -> DkeySettings; func save(_ s: DkeySettings) }`.

- [ ] **Step 1: Add the test target sources to project.yml**

In `project.yml`, under `dkeyTests: sources:`, add:

```yaml
      - path: Tests/AppTests
```

Then regenerate: `xcodegen generate` (or the project's usual generation step).

- [ ] **Step 2: Write the failing round-trip test**

Create `Tests/AppTests/SettingsStoreTests.swift`:

```swift
import XCTest
@testable import dkey

final class SettingsStoreTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "dkey.tests.\(UUID().uuidString)")!
        return d
    }

    func testDefaultsWhenEmpty() {
        let store = SettingsStore(defaults: freshDefaults())
        XCTAssertEqual(store.load(), DkeySettings.defaults)
    }

    func testRoundTrip() {
        let store = SettingsStore(defaults: freshDefaults())
        var s = DkeySettings.defaults
        s.inputMethod = .vni
        s.useModernOrthography = false
        s.switchKeyStatus = 0x7A000206
        s.isVietnamese = false
        store.save(s)
        XCTAssertEqual(store.load(), s)
    }

    func testCorruptJSONFallsBackToDefaults() {
        let d = freshDefaults()
        d.set(Data("not json".utf8), forKey: "dkey.settings.v1")
        let store = SettingsStore(defaults: d)
        XCTAssertEqual(store.load(), DkeySettings.defaults)
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -15`
Expected: compile failure — `DkeySettings` / `SettingsStore` undefined.

- [ ] **Step 4: Implement the model and store**

Create `Sources/App/DkeySettings.swift`:

```swift
import Foundation

struct DkeySettings: Codable, Equatable {
    var inputMethod: InputMethod
    var useModernOrthography: Bool
    var switchKeyStatus: Int32
    var isVietnamese: Bool

    static let defaults = DkeySettings(
        inputMethod: .telex,
        useModernOrthography: true,
        switchKeyStatus: 0x7A000206,
        isVietnamese: true
    )
}
```

Create `Sources/App/SettingsStore.swift`:

```swift
import Foundation

struct SettingsStore {
    static let key = "dkey.settings.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> DkeySettings {
        guard let data = defaults.data(forKey: Self.key),
              let s = try? JSONDecoder().decode(DkeySettings.self, from: data)
        else { return .defaults }
        return s
    }

    func save(_ s: DkeySettings) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -15`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add project.yml dkey.xcodeproj Sources/App/DkeySettings.swift Sources/App/SettingsStore.swift Tests/AppTests/SettingsStoreTests.swift
git commit -m "feat(app): add DkeySettings + SettingsStore (UserDefaults persistence)"
```

---

## Task 5: Wire settings into AppState

`AppState` loads settings on init, applies them to the controller/engine, and persists + applies on every change.

**Files:**
- Modify: `Sources/App/AppState.swift`
- Modify: `Sources/Platform/InputController.swift` (sync helpers)

**Interfaces:**
- Consumes: `SettingsStore`, `DkeySettings`, `InputMethod`, `InputController`, `TelexEngine.inputMethod`/`useModernOrthography`.
- Produces: `AppState.inputMethod` (`@Published`), `AppState.useModernOrthography` (`@Published`), a persisted `switchKeyStatus`, and `InputController.applySettings(...)`.

- [ ] **Step 1: Add a settings-apply helper to InputController**

In `Sources/Platform/InputController.swift`, add (keeps engine wiring in one place):

```swift
    /// Apply UI-driven config to the engine + hotkey. Resets the session.
    public func apply(inputMethod: InputMethod, modernOrthography: Bool, switchKeyStatus: Int32) {
        engine.inputMethod = inputMethod
        engine.useModernOrthography = modernOrthography
        self.switchKeyStatus = switchKeyStatus
        engine.newSession()
    }
```

- [ ] **Step 2: Load + publish + persist in AppState**

In `Sources/App/AppState.swift`:
- Add `private let store = SettingsStore()`.
- Add published properties with `didSet` persistence, mirroring the existing `isVietnamese` pattern:

```swift
    @Published var inputMethod: InputMethod = .telex {
        didSet { if !_isReflecting { controller.engine.inputMethod = inputMethod; controller.engine.newSession(); persist() } }
    }
    @Published var useModernOrthography: Bool = true {
        didSet { if !_isReflecting { controller.engine.useModernOrthography = useModernOrthography; controller.engine.newSession(); persist() } }
    }
```
- Extend the existing `isVietnamese` and `switchKeyStatus` `didSet` to also `persist()` (and have `switchKeyStatus.didSet` set `controller.switchKeyStatus = switchKeyStatus`).
- Replace the `private init()` body to load and apply:

```swift
    private init() {
        let s = store.load()
        _isReflecting = true
        isVietnamese = s.isVietnamese
        inputMethod = s.inputMethod
        useModernOrthography = s.useModernOrthography
        switchKeyStatus = s.switchKeyStatus
        _isReflecting = false
        controller.apply(inputMethod: s.inputMethod, modernOrthography: s.useModernOrthography, switchKeyStatus: s.switchKeyStatus)
        controller.setVietnamese(s.isVietnamese)
    }

    private func persist() {
        store.save(DkeySettings(inputMethod: inputMethod,
                                useModernOrthography: useModernOrthography,
                                switchKeyStatus: switchKeyStatus,
                                isVietnamese: isVietnamese))
    }
```

(Setting properties under `_isReflecting = true` avoids the `didSet` firing during load.)

- [ ] **Step 3: Write a smoke test for the wiring**

Add to `Tests/AppTests/SettingsStoreTests.swift` a test that AppState-style apply reaches the engine (pure, no UI):

```swift
    @MainActor
    func testControllerApplyReachesEngine() {
        let c = InputController()
        c.apply(inputMethod: .vni, modernOrthography: false, switchKeyStatus: 0x7A000206)
        XCTAssertEqual(c.engine.inputMethod, .vni)
        XCTAssertFalse(c.engine.useModernOrthography)
        XCTAssertEqual(c.switchKeyStatus, 0x7A000206)
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -15`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Sources/App/AppState.swift Sources/Platform/InputController.swift Tests/AppTests/SettingsStoreTests.swift
git commit -m "feat(app): load/apply/persist typing settings via AppState"
```

---

## Task 6: Switch-key bitfield codec

A pure function encoding a captured shortcut into the `switchKeyStatus` bitfield, with validation. Isolated so it's testable without AppKit.

**Files:**
- Create: `Sources/App/SwitchKeyCodec.swift`
- Create: `Tests/AppTests/SwitchKeyCodecTests.swift`

**Interfaces:**
- Produces: `enum SwitchKeyCodec { static func encode(keyCode: UInt16, displayASCII: UInt8, control: Bool, option: Bool, command: Bool, shift: Bool) -> Int32?; }` — returns `nil` when no modifier is present.

- [ ] **Step 1: Write the failing codec tests**

Create `Tests/AppTests/SwitchKeyCodecTests.swift`:

```swift
import XCTest
@testable import dkey

final class SwitchKeyCodecTests: XCTestCase {
    func testEncodeOptionZMatchesDefault() {
        // Z keyCode = 0x06, display 'z' = 0x7A, Option → 0x200.
        let status = SwitchKeyCodec.encode(keyCode: 0x06, displayASCII: 0x7A,
                                           control: false, option: true, command: false, shift: false)
        XCTAssertEqual(status, 0x7A000206)
    }

    func testEncodeControlShift() {
        let status = SwitchKeyCodec.encode(keyCode: 0x06, displayASCII: 0x7A,
                                           control: true, option: false, command: false, shift: true)
        XCTAssertEqual(status, Int32(0x7A000000 | 0x100 | 0x800 | 0x06))
    }

    func testRejectNoModifier() {
        XCTAssertNil(SwitchKeyCodec.encode(keyCode: 0x06, displayASCII: 0x7A,
                                           control: false, option: false, command: false, shift: false))
    }

    func testRoundTripThroughHotkeyDescription() {
        let status = SwitchKeyCodec.encode(keyCode: 0x06, displayASCII: 0x7A,
                                           control: false, option: true, command: false, shift: false)!
        XCTAssertEqual(AppState.hotkeyDescription(status), "⌥Z")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -15`
Expected: compile failure — `SwitchKeyCodec` undefined.

- [ ] **Step 3: Implement the codec**

Create `Sources/App/SwitchKeyCodec.swift`:

```swift
import Foundation

/// Encodes a captured shortcut into the switchKeyStatus bitfield understood by
/// HotkeyMatcher and AppState.hotkeyDescription:
///   byte low (&0xFF) = keyCode, 0x100/200/400/800 = ⌃/⌥/⌘/⇧, byte high (>>24) = display ASCII.
enum SwitchKeyCodec {
    static func encode(keyCode: UInt16, displayASCII: UInt8,
                       control: Bool, option: Bool, command: Bool, shift: Bool) -> Int32? {
        guard control || option || command || shift else { return nil }  // require a modifier
        var status: Int32 = Int32(displayASCII) << 24
        if control { status |= 0x100 }
        if option  { status |= 0x200 }
        if command { status |= 0x400 }
        if shift   { status |= 0x800 }
        status |= Int32(keyCode & 0xFF)
        return status
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -15`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Sources/App/SwitchKeyCodec.swift Tests/AppTests/SwitchKeyCodecTests.swift
git commit -m "feat(app): switch-key bitfield codec with modifier validation"
```

---

## Task 7: KeyRecorderField view

An `NSViewRepresentable` that captures the next keystroke (with modifiers), encodes it via `SwitchKeyCodec`, and reports the new status. UI glue — no unit test (AppKit first-responder); verified in Task 8's manual smoke.

**Files:**
- Create: `Sources/App/KeyRecorderField.swift`

**Interfaces:**
- Consumes: `SwitchKeyCodec.encode(...)`, `AppState.hotkeyDescription(_:)`.
- Produces: `struct KeyRecorderField: View` with `init(status: Binding<Int32>)`.

- [ ] **Step 1: Implement the recorder**

Create `Sources/App/KeyRecorderField.swift`:

```swift
import SwiftUI
import AppKit

/// Click to record; the next keyDown (with ≥1 modifier) becomes the switch key.
struct KeyRecorderField: View {
    @Binding var status: Int32
    @State private var recording = false

    var body: some View {
        Button {
            recording.toggle()
        } label: {
            Text(recording ? "Bấm tổ hợp phím…" : AppState.hotkeyDescription(status))
                .frame(minWidth: 90)
        }
        .background(KeyCaptureView(recording: $recording) { keyCode, ascii, ctrl, opt, cmd, shift in
            if let s = SwitchKeyCodec.encode(keyCode: keyCode, displayASCII: ascii,
                                             control: ctrl, option: opt, command: cmd, shift: shift) {
                status = s
            }
            recording = false
        })
        if recording {
            Text("Cần ít nhất 1 phím bổ trợ (⌃⌥⌘⇧).")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    @Binding var recording: Bool
    let onCapture: (_ keyCode: UInt16, _ ascii: UInt8, _ ctrl: Bool, _ opt: Bool, _ cmd: Bool, _ shift: Bool) -> Void

    func makeNSView(context: Context) -> CaptureNSView {
        let v = CaptureNSView()
        v.onCapture = onCapture
        return v
    }
    func updateNSView(_ v: CaptureNSView, context: Context) {
        v.onCapture = onCapture
        if recording { DispatchQueue.main.async { v.window?.makeFirstResponder(v) } }
    }

    final class CaptureNSView: NSView {
        var onCapture: ((UInt16, UInt8, Bool, Bool, Bool, Bool) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with e: NSEvent) {
            let f = e.modifierFlags
            let ascii = (e.charactersIgnoringModifiers?.uppercased().unicodeScalars.first?.value)
                .flatMap { $0 < 128 ? UInt8($0) : nil } ?? 0
            onCapture?(e.keyCode,
                       ascii,
                       f.contains(.control), f.contains(.option), f.contains(.command), f.contains(.shift))
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug build 2>&1 | tail -8`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Sources/App/KeyRecorderField.swift
git commit -m "feat(app): KeyRecorderField for capturing the switch key"
```

---

## Task 8: TypingSettingsView + tab wiring

The visible "Kiểu gõ" tab: typing-method picker, tone-style picker, switch-key recorder — bound to `AppState`. Replaces the placeholder.

**Files:**
- Create: `Sources/App/Views/TypingSettingsView.swift`
- Modify: `Sources/App/Views/SettingsRootView.swift`

**Interfaces:**
- Consumes: `AppState.inputMethod`, `AppState.useModernOrthography`, `AppState.switchKeyStatus`, `KeyRecorderField`.

- [ ] **Step 1: Build the tab view**

Create `Sources/App/Views/TypingSettingsView.swift`:

```swift
import SwiftUI

struct TypingSettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Picker("Kiểu gõ:", selection: $state.inputMethod) {
                Text("Telex").tag(InputMethod.telex)
                Text("VNI").tag(InputMethod.vni)
            }
            .pickerStyle(.segmented)

            Picker("Kiểu bỏ dấu:", selection: $state.useModernOrthography) {
                Text("Mới (hoà, uý)").tag(true)
                Text("Cũ (hòa, úy)").tag(false)
            }
            .pickerStyle(.radioGroup)

            LabeledContent("Phím chuyển:") {
                KeyRecorderField(status: $state.switchKeyStatus)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 460, alignment: .leading)
    }
}
```

- [ ] **Step 2: Route the `.typing` tab to it**

In `Sources/App/Views/SettingsRootView.swift`, replace the `detail:` closure so `.typing` renders the real view:

```swift
        } detail: {
            Group {
                switch state.selectedPage {
                case .typing: TypingSettingsView()
                default:      placeholder(for: state.selectedPage)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
```

- [ ] **Step 3: Build**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug build 2>&1 | tail -8`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Full test pass (regression gate)**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -8`
Expected: `TEST SUCCEEDED` — all engine (Telex + VNI), parity (both corpora), and app tests green.

- [ ] **Step 5: Manual smoke (per `scripts/verify-phase2.md` style)**

Launch the built app, open Cài đặt → Kiểu gõ. Verify: switch to **VNI**, type `vie6t65` / `ddo6ng2` in TextEdit → `việt` / `đồng`; toggle tone style; record a new switch key (e.g. ⌃⇧) and confirm the menu shows it and the new combo toggles VI/EN; quit and relaunch → all choices persisted.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/Views/TypingSettingsView.swift Sources/App/Views/SettingsRootView.swift
git commit -m "feat(app): Kiểu gõ settings tab (method, tone style, switch key)"
```

---

## Self-Review

**1. Spec coverage:**
- VNI engine (marks/circumflex/horn/breve/đ/remove/fallthrough) → Tasks 1–2. ✅
- Unicode NFC reuse → no new code table introduced. ✅
- VNI parity corpus via oracle → Task 3. ✅
- No Telex regression → regression gate in every task's test step + Task 8 Step 4. ✅
- Shared persistence (Codable/UserDefaults) → Task 4. ✅
- Live apply + persist on change, load on init → Task 5. ✅
- Free-capture switch-key recorder + bitfield + validation → Tasks 6–7, tab in Task 8. ✅
- 3 core controls (method / tone style / switch key), code table deferred → Task 8. ✅
- Defaults (Telex/modern/⌥Z/VI-on) → `DkeySettings.defaults` (Task 4), engine default (Task 1). ✅

**2. Placeholder scan:** No TBD/TODO; every code step shows complete code; the one judgement-call area (VNI vowel selection) is pinned to OpenKey line refs + validated by the Task 3 corpus. ✅

**3. Type consistency:** `InputMethod` (Task 1) is used identically in `DkeySettings` (Task 4), `InputController.apply` (Task 5), and `TypingSettingsView` (Task 8). `SwitchKeyCodec.encode` signature (Task 6) matches its caller in `KeyRecorderField` (Task 7). `type(_:modern:method:engine:)` defined in Task 1 is used by VNITests (Tasks 1–2) and ParityTests (Task 3). `controller.apply(...)` defined in Task 5 matches its AppState caller. ✅

**Note on the one risk area:** VNI vowel-target selection (`handleVNIAOEW`) is the likeliest place for a port bug. It is intentionally guarded twice: curated word tests (Task 2) and the oracle-defined parity corpus (Task 3). Treat OpenKey as ground truth when a mismatch appears.
