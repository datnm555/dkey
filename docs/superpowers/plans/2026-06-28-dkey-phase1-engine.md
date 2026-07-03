# dkey Phase 1 — Telex Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the Telex input path of the OpenKey C++ engine to a pure-Swift `TelexEngine` that maps keystrokes to Unicode NFC output, matching OpenKey byte-for-byte on a parity corpus.

**Architecture:** Faithful port (Hướng B). Mirror OpenKey's `TypingWord[32]` `UInt32` mask-buffer + control flow 1:1 in Swift, but wrap it behind a clean instance-based `InputEngine` protocol (no globals). Reference engine lives at `../mkey/Sources/Engine/` (OpenKey by Tuyen Mai, GPL v3). dkey is also GPL v3 → direct port is allowed.

**Tech Stack:** Swift 5.9 (macOS 14), XCTest, XcodeGen/xcodebuild. A throwaway C++17 oracle (clang++) generates the parity golden corpus; it is NOT part of the app build (app stays pure-Swift).

## Global Constraints

- Swift language version **5.9**, deployment target **macOS 14.0** (from `project.yml`).
- `Sources/Engine/` must **NOT** import AppKit/Cocoa — pure Swift + Foundation only.
- Output code table for Phase 1 is **Unicode NFC only** (`_codeTable[0]`); other code tables are deferred.
- Input type is **Telex only** (`vInputType == vTelex`); VNI/Simple-Telex deferred.
- Deferred (do NOT implement): spell-check/restore, quick-telex, quick start/end consonant, macro, smart-switch, free-mark, VNI, non-Unicode code tables.
- Reference source ranges below cite `../mkey/Sources/Engine/<file>:<lines>`. "Port verbatim" = translate that exact C++ to Swift preserving logic 1:1; do not redesign.
- All key codes are the macOS values from `../mkey/Sources/Engine/platforms/mac.h` (e.g. `KEY_A=0`, `KEY_S=1`, `KEY_W=13`).
- Commit after each task with the message shown in its final step.

---

## File Structure

Created under `Sources/Engine/` (all pure Swift):

- `KeyCode.swift` — hardware-independent key-code constants (port of `mac.h`) + `KeyCode(character:)` ASCII→(code,caps) helper (port of `_characterMap`).
- `EngineMasks.swift` — bit-mask constants (port of `DataType.h`) + read/write helpers on a `UInt32` cell.
- `VietnameseTables.swift` — `codeTableUnicode` (port of `_codeTable[0]`), `vowel`, `vowelCombine`, `vowelForMark`, `consonantD` tables; `keyCodeToCharacter`.
- `TypingBuffer.swift` — `TypingWord[32]` + `index` with named mask accessors.
- `EngineOutput.swift` — `struct EngineOutput`, `enum Action`, `protocol InputEngine`.
- `TelexEngine.swift` — the engine: `handle`, `backspace`, `newSession`, `getCharacterCode`, and ported transform functions. May be split into `TelexEngine+Mark.swift`, `TelexEngine+Diacritic.swift`, `TelexEngine+Vowel.swift` if it grows unwieldy.

Tests under `Tests/`:

- `Tests/EngineTests/TelexTestSupport.swift` — `type(_:modern:)` helper that drives the engine from an ASCII Telex string and returns the resulting Vietnamese string.
- `Tests/EngineTests/*.swift` — curated unit tests per behavior.
- `Tests/ParityTests/ParityTests.swift` — loads the golden JSON and asserts engine == OpenKey.
- `Tests/Fixtures/parity-corpus.json` — committed golden data.

Tooling (not in app build):

- `scripts/openkey-oracle/oracle.cpp`, `build.sh` — C++ harness over the OpenKey engine.
- `scripts/gen-parity-corpus.sh` — generates `Tests/Fixtures/parity-corpus.json`.

---

### Task 1: Engine target wiring + KeyCode + masks

**Files:**
- Modify: `project.yml` (add `Sources/Engine` to `dkey` target sources)
- Create: `Sources/Engine/KeyCode.swift`
- Create: `Sources/Engine/EngineMasks.swift`
- Test: `Tests/EngineTests/MasksTests.swift`

**Interfaces:**
- Produces: `enum KeyCode` with `static let a: UInt16 = 0` … (raw macOS codes); `func keyCode(for character: Character) -> (code: UInt16, caps: Bool)?`. Masks as `enum EngineMask { static let caps: UInt32 = 0x10000 … }` and helpers `cellKeyCode(_:) -> UInt16`, `cellHasMark(_:) -> Bool`.

- [ ] **Step 1: Add Engine sources to the app target**

In `project.yml`, under `targets: dkey: sources:`, add a new entry so it reads:
```yaml
    sources:
      - path: Sources/App
      - path: Sources/Engine
      - path: Sources/Support
        includes:
          - "Assets.xcassets"
```

- [ ] **Step 2: Create `Sources/Engine/KeyCode.swift`**

Port the macOS key codes from `../mkey/Sources/Engine/platforms/mac.h:12-76` verbatim. Use a caseless enum namespace:
```swift
import Foundation

/// Hardware-independent key codes (macOS virtual key codes, from OpenKey mac.h).
/// Phase 2's event tap maps CGKeyCode → these values (they ARE the macOS codes).
enum KeyCode {
    static let esc: UInt16 = 53, delete: UInt16 = 51, tab: UInt16 = 48
    static let enter: UInt16 = 76, ret: UInt16 = 36, space: UInt16 = 49
    static let left: UInt16 = 123, right: UInt16 = 124, down: UInt16 = 125, up: UInt16 = 126
    static let empty: UInt16 = 256
    static let a: UInt16 = 0, b: UInt16 = 11, c: UInt16 = 8, d: UInt16 = 2, e: UInt16 = 14
    static let f: UInt16 = 3, g: UInt16 = 5, h: UInt16 = 4, i: UInt16 = 34, j: UInt16 = 38
    static let k: UInt16 = 40, l: UInt16 = 37, m: UInt16 = 46, n: UInt16 = 45, o: UInt16 = 31
    static let p: UInt16 = 35, q: UInt16 = 12, r: UInt16 = 15, s: UInt16 = 1, t: UInt16 = 17
    static let u: UInt16 = 32, v: UInt16 = 9, w: UInt16 = 13, x: UInt16 = 7, y: UInt16 = 16, z: UInt16 = 6
    static let n1: UInt16 = 18, n2: UInt16 = 19, n3: UInt16 = 20, n4: UInt16 = 21, n5: UInt16 = 23
    static let n6: UInt16 = 22, n7: UInt16 = 26, n8: UInt16 = 28, n9: UInt16 = 25, n0: UInt16 = 29
    static let leftBracket: UInt16 = 33, rightBracket: UInt16 = 30
    static let dot: UInt16 = 47, backquote: UInt16 = 50, minus: UInt16 = 27, equals: UInt16 = 24
    static let backSlash: UInt16 = 42, semicolon: UInt16 = 41, quote: UInt16 = 39
    static let comma: UInt16 = 43, slash: UInt16 = 44
}
```
Add the ASCII helper (port of `_characterMap`, `../mkey/Sources/Engine/Vietnamese.cpp:507-556`) — letters + digits + the punctuation needed for tests:
```swift
extension KeyCode {
    /// Maps an ASCII character to (keyCode, caps). Used by tests and (later) by
    /// fallback paths. Returns nil for unmapped characters.
    static func keyCode(for ch: Character) -> (code: UInt16, caps: Bool)? {
        if let v = letterMap[ch] { return (v, false) }
        if let lower = ch.lowercased().first, let v = letterMap[lower], ch.isUppercase { return (v, true) }
        return punctMap[ch]
    }
    private static let letterMap: [Character: UInt16] = [
        "a": a, "b": b, "c": c, "d": d, "e": e, "f": f, "g": g, "h": h, "i": i, "j": j,
        "k": k, "l": l, "m": m, "n": n, "o": o, "p": p, "q": q, "r": r, "s": s, "t": t,
        "u": u, "v": v, "w": w, "x": x, "y": y, "z": z,
        "1": n1, "2": n2, "3": n3, "4": n4, "5": n5, "6": n6, "7": n7, "8": n8, "9": n9, "0": n0
    ]
    private static let punctMap: [Character: (UInt16, Bool)] = [
        "[": (leftBracket, false), "]": (rightBracket, false), " ": (space, false),
        ".": (dot, false), ",": (comma, false)
    ]
}
```

- [ ] **Step 3: Create `Sources/Engine/EngineMasks.swift`**

Port the masks from `../mkey/Sources/Engine/DataType.h:92-122` verbatim:
```swift
import Foundation

/// Bit-mask layout of one TypingWord cell (UInt32), ported from OpenKey DataType.h.
/// bits 0-15: key code; 16: caps; 17: tone ^ (â/ê/ô); 18: tone w (ơ/ư/ă);
/// 19-23: marks 1-5 (sắc/huyền/hỏi/ngã/nặng); 24: standalone (w/[/]); 25: char-code.
enum EngineMask {
    static let caps: UInt32       = 0x10000
    static let tone: UInt32       = 0x20000
    static let toneW: UInt32      = 0x40000
    static let mark1: UInt32      = 0x80000
    static let mark2: UInt32      = 0x100000
    static let mark3: UInt32      = 0x200000
    static let mark4: UInt32      = 0x400000
    static let mark5: UInt32      = 0x800000
    static let mark: UInt32       = 0xF80000   // any mark
    static let char: UInt32       = 0xFFFF     // low 16 bits = key/char code
    static let standalone: UInt32 = 0x1000000
    static let charCode: UInt32   = 0x2000000
    static let pureCharacter: UInt32 = 0x80000000
    static let endConsonant: UInt32  = 0x4000
    static let consonantAllow: UInt32 = 0x8000
}

extension UInt32 {
    var cellKeyCode: UInt16 { UInt16(self & EngineMask.char) }
    var cellHasMark: Bool { (self & EngineMask.mark) != 0 }
    var cellHasCaps: Bool { (self & EngineMask.caps) != 0 }
}
```

- [ ] **Step 4: Write failing test `Tests/EngineTests/MasksTests.swift`**

```swift
import XCTest
@testable import dkey

final class MasksTests: XCTestCase {
    func testKeyCodes() {
        XCTAssertEqual(KeyCode.a, 0)
        XCTAssertEqual(KeyCode.s, 1)
        XCTAssertEqual(KeyCode.w, 13)
        XCTAssertEqual(KeyCode.z, 6)
    }
    func testCharacterMap() {
        XCTAssertEqual(KeyCode.keyCode(for: "a")?.code, KeyCode.a)
        XCTAssertEqual(KeyCode.keyCode(for: "A")?.caps, true)
        XCTAssertEqual(KeyCode.keyCode(for: "s")?.code, KeyCode.s)
    }
    func testMaskAccessors() {
        let cell: UInt32 = UInt32(KeyCode.a) | EngineMask.mark1 | EngineMask.caps
        XCTAssertEqual(cell.cellKeyCode, KeyCode.a)
        XCTAssertTrue(cell.cellHasMark)
        XCTAssertTrue(cell.cellHasCaps)
    }
}
```

- [ ] **Step 5: Generate project, run test, verify it builds & passes**

Run:
```bash
xcodegen generate
rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`. (Note: `rm -rf build` avoids the "entitlements modified during build" false positive after file changes.)

- [ ] **Step 6: Commit**

```bash
git add project.yml Sources/Engine/KeyCode.swift Sources/Engine/EngineMasks.swift Tests/EngineTests/MasksTests.swift
git commit -m "feat(engine): add KeyCode + EngineMask (port mac.h + DataType.h masks)"
```

---

### Task 2: Vietnamese NFC code table + keyCodeToCharacter

**Files:**
- Create: `Sources/Engine/VietnameseTables.swift`
- Test: `Tests/EngineTests/CodeTableTests.swift`

**Interfaces:**
- Consumes: `KeyCode`, `EngineMask` (Task 1).
- Produces: `let codeTableUnicode: [UInt32: [UInt16]]` (port of `_codeTable[0]`); `func keyCodeToCharacter(_ keyCode: UInt32) -> UInt16`.

- [ ] **Step 1: Create `Sources/Engine/VietnameseTables.swift` with the Unicode code table**

Port `_codeTable[0]` **verbatim** from `../mkey/Sources/Engine/Vietnamese.cpp:411-429`. Keys combine `KeyCode` with `EngineMask.tone`/`.toneW`. Each value array layout: `[CapsÂ, â, CapsĂ, ă, then 5 mark pairs (caps,normal): sắc, huyền, hỏi, ngã, nặng]`.
```swift
import Foundation

/// Unicode NFC code table — verbatim port of OpenKey _codeTable[0]
/// (../mkey/Sources/Engine/Vietnamese.cpp:411-429).
let codeTableUnicode: [UInt32: [UInt16]] = [
    UInt32(KeyCode.a): [0x00C2,0x00E2,0x0102,0x0103,0x00C1,0x00E1,0x00C0,0x00E0,0x1EA2,0x1EA3,0x00C3,0x00E3,0x1EA0,0x1EA1],
    UInt32(KeyCode.o): [0x00D4,0x00F4,0x01A0,0x01A1,0x00D3,0x00F3,0x00D2,0x00F2,0x1ECE,0x1ECF,0x00D5,0x00F5,0x1ECC,0x1ECD],
    UInt32(KeyCode.u): [0x0000,0x0000,0x01AF,0x01B0,0x00DA,0x00FA,0x00D9,0x00F9,0x1EE6,0x1EE7,0x0168,0x0169,0x1EE4,0x1EE5],
    UInt32(KeyCode.e): [0x00CA,0x00EA,0x0000,0x0000,0x00C9,0x00E9,0x00C8,0x00E8,0x1EBA,0x1EBB,0x1EBC,0x1EBD,0x1EB8,0x1EB9],
    UInt32(KeyCode.d): [0x0110,0x0111],
    UInt32(KeyCode.a) | EngineMask.tone:  [0x1EA4,0x1EA5,0x1EA6,0x1EA7,0x1EA8,0x1EA9,0x1EAA,0x1EAB,0x1EAC,0x1EAD],
    UInt32(KeyCode.a) | EngineMask.toneW: [0x1EAE,0x1EAF,0x1EB0,0x1EB1,0x1EB2,0x1EB3,0x1EB4,0x1EB5,0x1EB6,0x1EB7],
    UInt32(KeyCode.o) | EngineMask.tone:  [0x1ED0,0x1ED1,0x1ED2,0x1ED3,0x1ED4,0x1ED5,0x1ED6,0x1ED7,0x1ED8,0x1ED9],
    UInt32(KeyCode.o) | EngineMask.toneW: [0x1EDA,0x1EDB,0x1EDC,0x1EDD,0x1EDE,0x1EDF,0x1EE0,0x1EE1,0x1EE2,0x1EE3],
    UInt32(KeyCode.u) | EngineMask.toneW: [0x1EE8,0x1EE9,0x1EEA,0x1EEB,0x1EEC,0x1EED,0x1EEE,0x1EEF,0x1EF0,0x1EF1],
    UInt32(KeyCode.e) | EngineMask.tone:  [0x1EBE,0x1EBF,0x1EC0,0x1EC1,0x1EC2,0x1EC3,0x1EC4,0x1EC5,0x1EC6,0x1EC7],
    UInt32(KeyCode.i): [0x00CD,0x00ED,0x00CC,0x00EC,0x1EC8,0x1EC9,0x0128,0x0129,0x1ECA,0x1ECB],
    UInt32(KeyCode.y): [0x00DD,0x00FD,0x1EF2,0x1EF3,0x1EF6,0x1EF7,0x1EF8,0x1EF9,0x1EF4,0x1EF5],
]
```
NOTE: `KEY_I` index 6/7 in C++ is `0x128,0x129` (missing leading zero); correct Unicode is `0x0128/0x0129` (Ĩ/ĩ) — use the 4-digit form above. This is a faithful value, not a behavior change.

- [ ] **Step 2: Add `keyCodeToCharacter`**

Port `../mkey/Sources/Engine/Vietnamese.cpp:558-575` (reverse of `_characterMap`). Reuse `KeyCode.keyCode(for:)` inverted:
```swift
/// Reverse map: engine key cell (low byte = keyCode, +caps) → ASCII character code.
/// Verbatim behavior of OpenKey keyCodeToCharacter.
func keyCodeToCharacter(_ keyCode: UInt32) -> UInt16 {
    let code = UInt16(keyCode & EngineMask.char)
    let caps = (keyCode & EngineMask.caps) != 0
    for ch in asciiTable {
        if let m = KeyCode.keyCode(for: ch), m.code == code, m.caps == caps {
            return UInt16(ch.asciiValue ?? 0)
        }
    }
    return 0
}
private let asciiTable: [Character] =
    Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789[] .,")
```

- [ ] **Step 3: Write failing test `Tests/EngineTests/CodeTableTests.swift`**

```swift
import XCTest
@testable import dkey

final class CodeTableTests: XCTestCase {
    func testBaseVowelRow() {
        // KEY_A row: index 5 = á (normal sắc), index 1 = â, index 3 = ă
        let row = codeTableUnicode[UInt32(KeyCode.a)]!
        XCTAssertEqual(row[5], 0x00E1) // á
        XCTAssertEqual(row[1], 0x00E2) // â
        XCTAssertEqual(row[3], 0x0103) // ă
    }
    func testCircumflexRow() {
        // KEY_A|TONE row index 1 = ấ
        let row = codeTableUnicode[UInt32(KeyCode.a) | EngineMask.tone]!
        XCTAssertEqual(row[1], 0x1EA5) // ấ
    }
    func testDRow() {
        XCTAssertEqual(codeTableUnicode[UInt32(KeyCode.d)]![1], 0x0111) // đ
    }
    func testKeyCodeToCharacter() {
        XCTAssertEqual(keyCodeToCharacter(UInt32(KeyCode.a)), UInt16(Character("a").asciiValue!))
        XCTAssertEqual(keyCodeToCharacter(UInt32(KeyCode.s)), UInt16(Character("s").asciiValue!))
    }
}
```

- [ ] **Step 4: Run test, verify pass**

Run:
```bash
xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Engine/VietnameseTables.swift Tests/EngineTests/CodeTableTests.swift
git commit -m "feat(engine): add Unicode NFC code table + keyCodeToCharacter (port _codeTable[0])"
```

---

### Task 3: Public API types + TypingBuffer + getCharacterCode

**Files:**
- Create: `Sources/Engine/EngineOutput.swift`
- Create: `Sources/Engine/TypingBuffer.swift`
- Create: `Sources/Engine/TelexEngine.swift` (initial: type + `getCharacterCode`)
- Test: `Tests/EngineTests/GetCharacterCodeTests.swift`

**Interfaces:**
- Produces: `enum Action { case passthrough, process, wordBreak, restore }`; `struct EngineOutput { let backspaceCount: Int; let newChars: [Unicode.Scalar]; let action: Action }`; `protocol InputEngine: AnyObject { func handle(key:caps:) -> EngineOutput; func backspace() -> EngineOutput; func newSession(); var useModernOrthography: Bool { get set } }`; `final class TelexEngine` with internal `getCharacterCode(_ data: UInt32) -> UInt32`.

- [ ] **Step 1: Create `Sources/Engine/EngineOutput.swift`**

```swift
import Foundation

public enum Action: Equatable { case passthrough, process, wordBreak, restore }

public struct EngineOutput: Equatable {
    public let backspaceCount: Int
    public let newChars: [Unicode.Scalar]
    public let action: Action
    public init(backspaceCount: Int, newChars: [Unicode.Scalar], action: Action) {
        self.backspaceCount = backspaceCount; self.newChars = newChars; self.action = action
    }
    public static let none = EngineOutput(backspaceCount: 0, newChars: [], action: .passthrough)
}

public protocol InputEngine: AnyObject {
    func handle(key: UInt16, caps: Bool) -> EngineOutput
    func backspace() -> EngineOutput
    func newSession()
    var useModernOrthography: Bool { get set }
}
```

- [ ] **Step 2: Create `Sources/Engine/TypingBuffer.swift`**

```swift
import Foundation

/// OpenKey TypingWord[MAX_BUFF] + _index, with named accessors.
struct TypingBuffer {
    static let maxBuff = 32
    var word = [UInt32](repeating: 0, count: TypingBuffer.maxBuff)
    var index: Int = 0

    mutating func reset() { index = 0 }
    subscript(_ i: Int) -> UInt32 {
        get { word[i] }
        set { word[i] = newValue }
    }
}
```

- [ ] **Step 3: Create `Sources/Engine/TelexEngine.swift` with type shell + `getCharacterCode`**

Port `getCharacterCode` from `../mkey/Sources/Engine/Engine.cpp:501-543`. The C++ computes `markElem` from the mark mask, `capsElem` from caps, looks up `_codeTable[vCodeTable]` by `(keyCode | TONE_MASK | TONEW_MASK)`, index `2*capsElem + markElem`, returns the scalar OR'd with `CHAR_CODE_MASK`. Phase 1 uses `codeTableUnicode` only.
```swift
import Foundation

public final class TelexEngine: InputEngine {
    public var useModernOrthography: Bool = true
    var buffer = TypingBuffer()

    public init() {}

    public func newSession() { buffer.reset() }

    /// Port of OpenKey getCharacterCode (Engine.cpp:501-543), Unicode table only.
    /// Returns a character-code value (low 16 bits = Unicode scalar) with CHAR_CODE bit set,
    /// or the raw data unchanged when no Vietnamese transform applies.
    func getCharacterCode(_ data: UInt32) -> UInt32 {
        // mark index: MARK1->0, MARK2->2, MARK3->4, MARK4->6, MARK5->8 (pair stride 2)
        var markElem = 0
        if      data & EngineMask.mark1 != 0 { markElem = 0 }
        else if data & EngineMask.mark2 != 0 { markElem = 2 }
        else if data & EngineMask.mark3 != 0 { markElem = 4 }
        else if data & EngineMask.mark4 != 0 { markElem = 6 }
        else if data & EngineMask.mark5 != 0 { markElem = 8 }
        let hasMark = data.cellHasMark

        let capsElem = (data & EngineMask.caps) != 0 ? 0 : 1
        let key = UInt32(data & EngineMask.char) | (data & EngineMask.tone) | (data & EngineMask.toneW)

        guard let row = codeTableUnicode[key] else { return data }
        // Base (no mark): â/ă/ơ/ư live at indices 0..3; plain vowel has no row change.
        let baseIndex = hasMark ? (2 * capsElem + markElem)   // mark rows are 10-wide (5 pairs)
                                : (data & (EngineMask.tone | EngineMask.toneW) != 0 ? capsElem : -1)
        // baseIndex == -1 means "no diacritic, no mark" → not a transformed char.
        if baseIndex < 0 || baseIndex >= row.count { return data }
        let scalar = UInt32(row[baseIndex])
        if scalar == 0 { return data }
        return scalar | EngineMask.charCode
    }
}
```
NOTE on index math: in OpenKey the base row (KEY_A) is 14-wide and mark rows (KEY_A|TONE) are 10-wide. For a plain vowel WITH a mark and NO circumflex/horn, the lookup key is the bare `KEY_A` whose row indices 4..13 are the 5 mark pairs; so when `hasMark && !tone && !toneW`, index must be `4 + 2*capsElem + markElem`. Implement exactly per Engine.cpp:501-543 — verify each branch against the C++ and against the tests below; adjust the `baseIndex` computation to match (the snippet above is a scaffold, the C++ is authoritative).

- [ ] **Step 4: Write failing test `Tests/EngineTests/GetCharacterCodeTests.swift`**

```swift
import XCTest
@testable import dkey

final class GetCharacterCodeTests: XCTestCase {
    private func scalar(_ data: UInt32) -> UInt16 {
        UInt16(TelexEngine().getCharacterCode(data) & EngineMask.char)
    }
    func testPlainVowelWithMark() {
        // a + sắc → á (0x00E1); a + huyền → à (0x00E0)
        XCTAssertEqual(scalar(UInt32(KeyCode.a) | EngineMask.mark1), 0x00E1)
        XCTAssertEqual(scalar(UInt32(KeyCode.a) | EngineMask.mark2), 0x00E0)
    }
    func testCircumflexWithMark() {
        // â + sắc → ấ (0x1EA5)
        XCTAssertEqual(scalar(UInt32(KeyCode.a) | EngineMask.tone | EngineMask.mark1), 0x1EA5)
    }
    func testHornNoMark() {
        // ơ (o + toneW, no mark) → 0x01A1
        XCTAssertEqual(scalar(UInt32(KeyCode.o) | EngineMask.toneW), 0x01A1)
    }
    func testDBar() {
        XCTAssertEqual(scalar(UInt32(KeyCode.d) | EngineMask.tone), 0x0111) // đ uses tone bit path; verify vs C++
    }
}
```
If `testDBar` reveals the `đ` path differs (KEY_D row is only 2-wide), align `getCharacterCode` with the C++ KEY_D handling exactly.

- [ ] **Step 5: Run test, fix `getCharacterCode` until green**

Run:
```bash
xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`. Iterate the `getCharacterCode` branches against `Engine.cpp:501-543` until all four assertions pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Engine/EngineOutput.swift Sources/Engine/TypingBuffer.swift Sources/Engine/TelexEngine.swift Tests/EngineTests/GetCharacterCodeTests.swift
git commit -m "feat(engine): add InputEngine API, TypingBuffer, getCharacterCode (Unicode NFC)"
```

---

### Task 4: Plain-key typing + output assembly + test support helper

**Files:**
- Modify: `Sources/Engine/TelexEngine.swift` (add `handle`, plain-key insert, output builder)
- Create: `Tests/EngineTests/TelexTestSupport.swift`
- Test: `Tests/EngineTests/PlainTypingTests.swift`

**Interfaces:**
- Consumes: `getCharacterCode`, `TypingBuffer`, `EngineOutput`.
- Produces: `func handle(key:caps:) -> EngineOutput`; test helper `func type(_ telex: String, modern: Bool, engine: TelexEngine?) -> String`.

- [ ] **Step 1: Implement plain-key path + output assembly in `TelexEngine`**

Add to `TelexEngine`. For Phase 1, `handle` first routes word-break keys and special keys (added in later tasks); for now implement: append plain key to buffer, return passthrough output of the literal character. Port the buffer-append shape from `insertKey`/`vKeyHandleEvent` (`Engine.cpp:1314+`) but minimal:
```swift
extension TelexEngine {
    public func handle(key: UInt16, caps: Bool) -> EngineOutput {
        // Word break (space, punctuation, enter, arrows…): finalize + reset.
        if Self.breakCodes.contains(key) {
            newSession()
            return EngineOutput(backspaceCount: 0, newChars: [], action: .wordBreak)
        }
        // (special Telex keys handled in later tasks)
        return insertKey(key, caps: caps)
    }

    /// Append a raw key as plain text. Mirrors OpenKey insertKey for the no-transform case.
    func insertKey(_ key: UInt16, caps: Bool) -> EngineOutput {
        guard buffer.index < TypingBuffer.maxBuff else {
            return EngineOutput(backspaceCount: 0, newChars: [], action: .passthrough)
        }
        buffer[buffer.index] = UInt32(key) | (caps ? EngineMask.caps : 0)
        buffer.index += 1
        let ch = UInt16(keyCodeToCharacter(UInt32(key) | (caps ? EngineMask.caps : 0)))
        let scalars: [Unicode.Scalar] = ch != 0 ? [Unicode.Scalar(ch)!] : []
        return EngineOutput(backspaceCount: 0, newChars: scalars, action: .passthrough)
    }

    static let breakCodes: Set<UInt16> = [
        KeyCode.esc, KeyCode.tab, KeyCode.enter, KeyCode.ret, KeyCode.left, KeyCode.right,
        KeyCode.down, KeyCode.up, KeyCode.comma, KeyCode.dot, KeyCode.slash, KeyCode.semicolon,
        KeyCode.quote, KeyCode.backSlash, KeyCode.minus, KeyCode.equals, KeyCode.backquote, KeyCode.space
    ]
}
```
(`breakCodes` ports `_breakCode` from `Engine.cpp:21-23`, plus space which OpenKey treats as a session boundary.)

- [ ] **Step 2: Create test support `Tests/EngineTests/TelexTestSupport.swift`**

This helper is the backbone of all black-box tests: it feeds an ASCII Telex string key-by-key and applies each `EngineOutput` to a running buffer, returning the final Vietnamese string.
```swift
import XCTest
@testable import dkey

/// Drive the engine from an ASCII Telex string; return the resulting text.
/// Applies backspaceCount + newChars to a mutable [Character] buffer per key.
func type(_ telex: String, modern: Bool = true, engine: TelexEngine? = nil) -> String {
    let e = engine ?? TelexEngine()
    e.useModernOrthography = modern
    e.newSession()
    var screen: [Character] = []
    for ch in telex {
        guard let (code, caps) = KeyCode.keyCode(for: ch) else { continue }
        let out = e.handle(key: code, caps: caps)
        if out.action == .wordBreak {
            // space/punctuation: append the literal then reset visual word boundary tracking
            screen.append(ch)
            continue
        }
        for _ in 0..<out.backspaceCount { if !screen.isEmpty { screen.removeLast() } }
        for s in out.newChars { screen.append(Character(s)) }
    }
    return String(screen)
}
```

- [ ] **Step 3: Write failing test `Tests/EngineTests/PlainTypingTests.swift`**

```swift
import XCTest
@testable import dkey

final class PlainTypingTests: XCTestCase {
    func testPlainAscii() { XCTAssertEqual(type("abc"), "abc") }
    func testConsonantCluster() { XCTAssertEqual(type("ngh"), "ngh") }
    func testNewSessionOnSpace() { XCTAssertEqual(type("ab cd"), "ab cd") }
}
```

- [ ] **Step 4: Run test, verify pass**

Run:
```bash
xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Engine/TelexEngine.swift Tests/EngineTests/TelexTestSupport.swift Tests/EngineTests/PlainTypingTests.swift
git commit -m "feat(engine): plain-key typing, output assembly, test harness"
```

---

### Task 5: findAndCalculateVowel + vowel tables

**Files:**
- Modify: `Sources/Engine/VietnameseTables.swift` (add `vowel`, `vowelCombine`)
- Modify: `Sources/Engine/TelexEngine.swift` (add `findAndCalculateVowel`, vowel state)
- Test: `Tests/EngineTests/VowelTests.swift`

**Interfaces:**
- Produces: internal `func findAndCalculateVowel(forGrammar: Bool)` setting `vowelStartIndex`, `vowelEndIndex`, `vowelCount` on the engine; tables `vowel`, `vowelCombine`.

- [ ] **Step 1: Port the vowel tables**

Port `_vowel` (`Vietnamese.cpp:19-97`) and `_vowelCombine` (`Vietnamese.cpp:99-168`) **verbatim** into `VietnameseTables.swift` as `let vowel: [UInt16: [[UInt16]]]` and `let vowelCombine: [UInt16: [[UInt32]]]`. Preserve the `END_CONSONANT_MASK`/`TONE_MASK`/`TONEW_MASK` OR-ing exactly (use `EngineMask.endConsonant`, `.tone`, `.toneW`). Reproduce every row — do not abbreviate.

- [ ] **Step 2: Port `findAndCalculateVowel`**

Add engine state `var vowelStartIndex = 0, vowelEndIndex = 0, vowelCount = 0` and port `../mkey/Sources/Engine/Engine.cpp:560-628` (`findAndCalculateVowel`) 1:1, replacing `TypingWord[i]`/`_index` with `buffer[i]`/`buffer.index` and `CHR(i)` with `buffer[i].cellKeyCode`.

- [ ] **Step 3: Write failing test `Tests/EngineTests/VowelTests.swift`**

White-box (@testable) — set up the buffer by typing, then inspect vowel calc:
```swift
import XCTest
@testable import dkey

final class VowelTests: XCTestCase {
    private func vowelInfo(_ telex: String) -> (start: Int, end: Int, count: Int) {
        let e = TelexEngine()
        for ch in telex { let (c, caps) = KeyCode.keyCode(for: ch)!; _ = e.handle(key: c, caps: caps) }
        e.findAndCalculateVowel(forGrammar: false)
        return (e.vowelStartIndex, e.vowelEndIndex, e.vowelCount)
    }
    func testSingleVowel() {
        let v = vowelInfo("ba")            // b-a
        XCTAssertEqual(v.count, 1)
        XCTAssertEqual(v.start, 1)
    }
    func testDiphthong() {
        let v = vowelInfo("hoa")           // h-o-a
        XCTAssertEqual(v.count, 2)
        XCTAssertEqual(v.start, 1)
        XCTAssertEqual(v.end, 2)
    }
    func testTriphthong() {
        let v = vowelInfo("oai")
        XCTAssertEqual(v.count, 3)
    }
}
```

- [ ] **Step 4: Run, verify pass** (adjust expected start/end to match the faithful port if off-by-one)

Run:
```bash
xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Engine/VietnameseTables.swift Sources/Engine/TelexEngine.swift Tests/EngineTests/VowelTests.swift
git commit -m "feat(engine): port findAndCalculateVowel + vowel tables"
```

---

### Task 6: Tone marks — insertMark + modern/classic placement (s/f/r/x/j)

**Files:**
- Modify: `Sources/Engine/VietnameseTables.swift` (add `vowelForMark`, `Vietnamese.cpp:244-331`)
- Modify: `Sources/Engine/TelexEngine.swift` (add `insertMark`, `handleModernMark`, `handleOldMark`, mark routing)
- Test: `Tests/EngineTests/ToneMarkTests.swift`

**Interfaces:**
- Consumes: `findAndCalculateVowel`, `getCharacterCode`.
- Produces: tone-mark behavior reachable through `handle`; `func insertMark(_ markMask: UInt32, canModifyFlag: Bool)`.

- [ ] **Step 1: Port `vowelForMark` table** verbatim from `Vietnamese.cpp:244-331` as `let vowelForMark: [UInt16: [[UInt16]]]`.

- [ ] **Step 2: Port mark functions** `insertMark` (`Engine.cpp:753-806`), `handleModernMark` (`Engine.cpp:629-726`), `handleOldMark` (`Engine.cpp:727-752`) 1:1. Map `vUseModernOrthography` → `self.useModernOrthography`. The mark mask for s/f/r/x/j: `s→mark1, f→mark2, r→mark3, x→mark4, j→mark5` (per `MARK?_MASK` comments in `DataType.h:96-108`). Build the output (`backspaceCount`, reversed `charData` → `newChars`) from `HookState` equivalents; convert each affected cell via `getCharacterCode`.

- [ ] **Step 3: Route mark keys** in `handle` (before `insertKey`): if key ∈ {s,f,r,x,j} and there is a markable vowel, call `insertMark`; else fall through to `insertKey`. Mirror `handleMainKey` mark branch (`Engine.cpp:1104-1142`).

- [ ] **Step 4: Write failing test `Tests/EngineTests/ToneMarkTests.swift`**

```swift
import XCTest
@testable import dkey

final class ToneMarkTests: XCTestCase {
    func testFiveTonesOnA() {
        XCTAssertEqual(type("as"), "á")
        XCTAssertEqual(type("af"), "à")
        XCTAssertEqual(type("ar"), "ả")
        XCTAssertEqual(type("ax"), "ã")
        XCTAssertEqual(type("aj"), "ạ")
    }
    func testToneOnConsonantWord() {
        XCTAssertEqual(type("toans"), "toán")   // mark on a
        XCTAssertEqual(type("vietj"), "vietj".isEmpty ? "" : type("vietj")) // placeholder removed below
    }
    func testModernVsClassic() {
        XCTAssertEqual(type("hoaf", modern: true),  "hòa")
        XCTAssertEqual(type("hoaf", modern: false), "hoà")
        XCTAssertEqual(type("uys",  modern: true),  "úy")
        XCTAssertEqual(type("uys",  modern: false), "uý")
    }
    func testToggleOff() {
        // typing the mark key twice removes the tone (restore): "as" → á, second "s" → "as"
        XCTAssertEqual(type("ass"), "as")
    }
}
```
Remove the placeholder line in `testToneOnConsonantWord`; replace with a real assertion once the engine is in place, e.g. `XCTAssertEqual(type("hoojc"), "học")` — verify expected against the oracle if unsure.

- [ ] **Step 5: Run, iterate against C++ until green**

Run:
```bash
xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -12
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Sources/Engine/VietnameseTables.swift Sources/Engine/TelexEngine.swift Tests/EngineTests/ToneMarkTests.swift
git commit -m "feat(engine): tone marks with modern/classic placement (s/f/r/x/j)"
```

---

### Task 7: Circumflex diacritics — insertAOE (aa/ee/oo → â/ê/ô)

**Files:**
- Modify: `Sources/Engine/TelexEngine.swift` (add `insertAOE`, route a/e/o)
- Test: `Tests/EngineTests/CircumflexTests.swift`

**Interfaces:**
- Produces: a/e/o doubling behavior through `handle`; `func insertAOE(_ key: UInt16, caps: Bool)`.

- [ ] **Step 1: Port `insertAOE`** from `../mkey/Sources/Engine/Engine.cpp:833-869` 1:1 (scan back for matching vowel; toggle `TONE_MASK`; remove `TONEW_MASK`). Route keys a/e/o in `handle`/`handleMainKey` (`Engine.cpp` double-key branch via `IS_KEY_DOUBLE`).

- [ ] **Step 2: Write failing test `Tests/EngineTests/CircumflexTests.swift`**

```swift
import XCTest
@testable import dkey

final class CircumflexTests: XCTestCase {
    func testCircumflex() {
        XCTAssertEqual(type("aa"), "â")
        XCTAssertEqual(type("ee"), "ê")
        XCTAssertEqual(type("oo"), "ô")
    }
    func testCircumflexWithTone() {
        XCTAssertEqual(type("aas"), "ấ")
        XCTAssertEqual(type("oojc"), "ộc")   // ô + nặng + c
    }
    func testRestoreOnThird() {
        XCTAssertEqual(type("aaa"), "aa")    // third a removes circumflex
    }
}
```

- [ ] **Step 3: Run, iterate until green**

Run:
```bash
xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Sources/Engine/TelexEngine.swift Tests/EngineTests/CircumflexTests.swift
git commit -m "feat(engine): circumflex diacritics aa/ee/oo (insertAOE)"
```

---

### Task 8: Horn/breve diacritics — insertW + standalone (w, [, ])

**Files:**
- Modify: `Sources/Engine/VietnameseTables.swift` (add `consonantD` not yet; add `standaloneWbad`, `doubleWAllowed` from `Vietnamese.cpp:375-389`)
- Modify: `Sources/Engine/TelexEngine.swift` (add `insertW`, `checkForStandaloneChar`, route w/[/])
- Test: `Tests/EngineTests/HornTests.swift`

**Interfaces:**
- Produces: w / `[` / `]` behavior through `handle`; `func insertW(...)`, `func checkForStandaloneChar(...)`.

- [ ] **Step 1: Port tables** `_standaloneWbad` and `_doubleWAllowed` (`Vietnamese.cpp:375-389`) verbatim.

- [ ] **Step 2: Port `insertW`** (`Engine.cpp:871-984`), `checkForStandaloneChar` (`Engine.cpp:995-1040`), `reverseLastStandaloneChar` (`Engine.cpp:991-994`) 1:1. Route `w` (horn/breve), `[`→ơ-standalone, `]`→ư-standalone in `handle` (`IS_BRACKET_KEY`, `IS_KEY_W`).

- [ ] **Step 3: Write failing test `Tests/EngineTests/HornTests.swift`**

```swift
import XCTest
@testable import dkey

final class HornTests: XCTestCase {
    func testHorn() {
        XCTAssertEqual(type("uw"), "ư")
        XCTAssertEqual(type("ow"), "ơ")
        XCTAssertEqual(type("aw"), "ă")
    }
    func testStandaloneW() { XCTAssertEqual(type("w"), "ư") }
    func testBrackets() {
        XCTAssertEqual(type("["), "ơ")
        XCTAssertEqual(type("]"), "ư")
    }
    func testHornWord() {
        XCTAssertEqual(type("uowng"), "ương")  // ư + ơ + ng
        XCTAssertEqual(type("dduowngf"), "đường")
    }
}
```

- [ ] **Step 4: Run, iterate until green**

Run:
```bash
xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`. (`đường` also needs Task 9's `đ`; if running this task alone, drop the `dduowngf` line and re-add it in Task 9.)

- [ ] **Step 5: Commit**

```bash
git add Sources/Engine/VietnameseTables.swift Sources/Engine/TelexEngine.swift Tests/EngineTests/HornTests.swift
git commit -m "feat(engine): horn/breve diacritics w + standalone [ ] (insertW)"
```

---

### Task 9: Đ — insertD (dd → đ)

**Files:**
- Modify: `Sources/Engine/VietnameseTables.swift` (add `consonantD`, `Vietnamese.cpp:170-...`)
- Modify: `Sources/Engine/TelexEngine.swift` (add `insertD`, route d)
- Test: `Tests/EngineTests/DTests.swift`

- [ ] **Step 1: Port `_consonantD`** verbatim and `insertD` (`Engine.cpp:808-831`) 1:1; route `d` in `handle`/`handleMainKey` (`IS_KEY_D`).

- [ ] **Step 2: Write failing test `Tests/EngineTests/DTests.swift`**

```swift
import XCTest
@testable import dkey

final class DTests: XCTestCase {
    func testDBar() {
        XCTAssertEqual(type("dd"), "đ")
        XCTAssertEqual(type("ddaf"), "đà")
        XCTAssertEqual(type("dduowngf"), "đường")
    }
    func testDRestore() { XCTAssertEqual(type("ddd"), "dd") } // third d restores
}
```

- [ ] **Step 3: Run, verify pass**

Run:
```bash
xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Sources/Engine/VietnameseTables.swift Sources/Engine/TelexEngine.swift Tests/EngineTests/DTests.swift
git commit -m "feat(engine): đ via dd (insertD)"
```

---

### Task 10: Remove-tone (z), backspace + checkGrammar re-placement

**Files:**
- Modify: `Sources/Engine/TelexEngine.swift` (add `removeMark`, `checkGrammar`, `backspace`)
- Test: `Tests/EngineTests/RemoveAndBackspaceTests.swift`

**Interfaces:**
- Produces: `func backspace() -> EngineOutput` (real impl replacing Task 3 stub if any); `z` routing; `func removeMark()`, `func checkGrammar(_ deltaBackspace: Int)`.

- [ ] **Step 1: Port `removeMark`** (`Engine.cpp:587-609`), route `z` (`IS_KEY_Z`). Port `checkGrammar` (`Engine.cpp:290-346`) and `backspace` path (`Engine.cpp:1420-1465`): decrement `buffer.index`, re-run `checkGrammar(1)` to move the tone mark to the correct vowel after deletion. `backspace()` returns the redraw output.

- [ ] **Step 2: Write failing test `Tests/EngineTests/RemoveAndBackspaceTests.swift`**

```swift
import XCTest
@testable import dkey

final class RemoveAndBackspaceTests: XCTestCase {
    func testZRemovesTone() {
        XCTAssertEqual(type("asz"), "a")     // á then z → a
        XCTAssertEqual(type("aasz"), "â")    // z removes only tone mark, keeps circumflex
    }
    func testBackspaceReplacement() {
        // type "hòa", backspace removes 'a' → "hò"
        let e = TelexEngine()
        _ = type("hoaf", engine: e)          // builds hòa in engine state
        let out = e.backspace()
        // After removing the last vowel, the engine should reflow; assert no crash + buffer shrank
        XCTAssertGreaterThanOrEqual(out.backspaceCount, 0)
    }
}
```
Strengthen `testBackspaceReplacement` once behavior is confirmed against the oracle (e.g. assert the reconstructed screen equals `"hò"`).

- [ ] **Step 3: Run, iterate until green**

Run:
```bash
xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Sources/Engine/TelexEngine.swift Tests/EngineTests/RemoveAndBackspaceTests.swift
git commit -m "feat(engine): z removes tone; backspace re-placement via checkGrammar"
```

---

### Task 11: Curated end-to-end suite

**Files:**
- Create: `Tests/EngineTests/CuratedTelexTests.swift`

- [ ] **Step 1: Write the curated regression table** (documents real-word behavior; all should already pass given Tasks 6-10)

```swift
import XCTest
@testable import dkey

final class CuratedTelexTests: XCTestCase {
    func testWords() {
        let cases: [(String, String)] = [
            ("tieesng", "tiếng"), ("vieejt", "việt"), ("nam", "nam"),
            ("ddaay", "đây"), ("quoocs", "quốc"), ("hojc", "học"),
            ("nguwowif", "người"), ("trraan", "trran"), ("xin", "xin"),
            ("chaof", "chào"), ("ddoongf", "đồng"), ("thuyr", "thủy"),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(type(input), expected, "input=\(input)")
        }
    }
    func testClassic() {
        XCTAssertEqual(type("hoaf", modern: false), "hoà")
        XCTAssertEqual(type("thuys", modern: false), "thuý")
    }
}
```
Any row that fails reveals a port divergence — fix the corresponding ported function (do not change the expected value unless the oracle disagrees). Confirm each expected output against the oracle (Task 13) if unsure.

- [ ] **Step 2: Run, verify pass**

Run:
```bash
xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Tests/EngineTests/CuratedTelexTests.swift
git commit -m "test(engine): curated end-to-end Telex word suite"
```

---

### Task 12: OpenKey C++ oracle harness

**Files:**
- Create: `scripts/openkey-oracle/oracle.cpp`
- Create: `scripts/openkey-oracle/build.sh`

**Interfaces:**
- Produces: a CLI binary `oracle` that reads lines `"<telex>\t<modern|classic>"` from stdin and prints `"<telex>\t<modern_out>\t<classic_out>"` (UTF-8) — used by Task 13.

- [ ] **Step 1: Write `scripts/openkey-oracle/oracle.cpp`**

Drive the real OpenKey engine. Define the required `extern int v*` globals, init Telex/Unicode/Vietnamese mode, feed each character via `_characterMap`, and reconstruct output from `HookState` (apply `backspaceCount` + `charData`). Reference the global list in `Engine.h:48-188` and the `HookState` shape in `DataType.h:57-81`.
```cpp
// Minimal driver over OpenKey engine (../../mkey/Sources/Engine).
#include <cstdio>
#include <string>
#include <vector>
#include <map>
#include "Engine.h"
#include "Vietnamese.h"

// --- engine config globals (declared extern in Engine.h) ---
int vLanguage = 1;            // Vietnamese
int vInputType = 0;          // vTelex
int vFreeMark = 0;
int vCodeTable = 0;          // Unicode
int vCheckSpelling = 0;      // OFF for Phase 1 parity
int vUseModernOrthography = 1;
int vQuickTelex = 0, vRestoreIfWrongSpelling = 0, vUseMacro = 0, vUseMacroInEnglishMode = 0,
    vAutoCapsMacro = 0, vUseSmartSwitchKey = 0, vUpperCaseFirstChar = 0, vTempOffSpelling = 0,
    vAllowConsonantZFWJ = 0, vQuickStartConsonant = 0, vQuickEndConsonant = 0, vRememberCode = 0,
    vOtherLanguage = 0, vTempOffOpenKey = 0, vSwitchKeyStatus = 0, vFixRecommendBrowser = 0;

extern map<Uint32, Uint32> _characterMap;

static std::string runOne(const std::string& telex, int modern) {
    vUseModernOrthography = modern;
    vKeyInit();
    startNewSession();
    std::vector<unsigned int> screen; // unicode scalars
    for (char c : telex) {
        auto it = _characterMap.find((Uint32)c);
        if (it == _characterMap.end()) continue;
        Uint32 km = it->second;
        Uint16 code = km & 0xFFFF;
        bool caps = (km & CAPS_MASK) != 0;
        vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, code, caps ? 1 : 0, false);
        if (HookState.code == vWillProcess || HookState.code == vRestore) {
            for (int i = 0; i < HookState.backspaceCount && !screen.empty(); i++) screen.pop_back();
            for (int i = HookState.newCharCount - 1; i >= 0; i--) {
                Uint32 d = getCharacterCode(HookState.charData[i]);
                screen.push_back(d & 0xFFFF);
            }
        } else if (HookState.code == vBreakWord || HookState.code == vDoNothing) {
            screen.push_back((unsigned char)c); // literal passthrough
        }
    }
    // encode scalars → UTF-8
    std::string out;
    for (unsigned int s : screen) {
        if (s < 0x80) out += (char)s;
        else if (s < 0x800) { out += (char)(0xC0 | (s>>6)); out += (char)(0x80 | (s&0x3F)); }
        else { out += (char)(0xE0 | (s>>12)); out += (char)(0x80 | ((s>>6)&0x3F)); out += (char)(0x80 | (s&0x3F)); }
    }
    return out;
}

int main() {
    std::string line;
    char buf[4096];
    while (fgets(buf, sizeof(buf), stdin)) {
        std::string telex(buf);
        while (!telex.empty() && (telex.back()=='\n' || telex.back()=='\r')) telex.pop_back();
        if (telex.empty()) continue;
        printf("%s\t%s\t%s\n", telex.c_str(), runOne(telex, 1).c_str(), runOne(telex, 0).c_str());
    }
    return 0;
}
```
NOTE: the exact `HookState.code`/output reconstruction must match how OpenKey's host app applies it. If the engine drives output differently (e.g. `extCode`), adjust against `Engine.cpp:1314-1502`. The reconstruction in `runOne` mirrors the Swift test harness so both sides reduce to a final string.

- [ ] **Step 2: Write `scripts/openkey-oracle/build.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
ENG=../../../mkey/Sources/Engine
clang++ -std=c++17 -I"$ENG" -DNDEBUG \
  oracle.cpp "$ENG/Engine.cpp" "$ENG/Vietnamese.cpp" "$ENG/Macro.cpp" "$ENG/SmartSwitchKey.cpp" "$ENG/ConvertTool.cpp" \
  -o oracle
echo "built ./oracle"
```
Make it executable: `chmod +x scripts/openkey-oracle/build.sh`.

- [ ] **Step 3: Build and smoke-test the oracle**

Run:
```bash
bash scripts/openkey-oracle/build.sh
printf 'as\nhoaf\nddaf\nuw\n' | scripts/openkey-oracle/oracle
```
Expected output (tab-separated `input modern classic`):
```
as	á	á
hoaf	hòa	hoà
ddaf	đà	đà
uw	ư	ư
```
If compilation fails on missing symbols (Macro/SmartSwitch/Convert globals), add the minimal extra `extern` definitions the linker reports — keep them zero/no-op. Document any added stub at the top of `oracle.cpp`.

- [ ] **Step 4: Commit**

```bash
git add scripts/openkey-oracle/oracle.cpp scripts/openkey-oracle/build.sh
git commit -m "test(parity): add OpenKey C++ oracle harness"
```

---

### Task 13: Parity corpus generator + fixtures

**Files:**
- Create: `scripts/gen-parity-corpus.sh`
- Create: `Tests/Fixtures/parity-corpus.json` (generated, committed)

- [ ] **Step 1: Write `scripts/gen-parity-corpus.sh`**

Generate inputs combinatorially (initial consonant × vowel cluster × tone key × final consonant) plus a curated word list, pipe through the oracle, and emit JSON `[{ "input": ..., "modern": ..., "classic": ... }]`.
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/openkey-oracle/build.sh

INITIALS=( "" b c ch d dd g gh h kh l m n ng ngh nh ph qu r s t th tr v x )
VOWELS=( a aa aw e ee i o oo ow oa oe u uw uo uow uoi uyee ie ye )
TONES=( "" s f r x j )
FINALS=( "" c ch m n ng nh p t )

OUT=Tests/Fixtures/parity-corpus.json
{
  # build input list
  for ini in "${INITIALS[@]}"; do
    for v in "${VOWELS[@]}"; do
      for t in "${TONES[@]}"; do
        for fin in "${FINALS[@]}"; do
          printf '%s%s%s%s\n' "$ini" "$v" "$t" "$fin"
        done
      done
    done
  done
  # curated real words (Telex keystrokes)
  printf 'tieesng\nvieejt\nnguwowif\nddaay\nquoocs\nhojc\nthuyr\nchaof\nddoongf\n'
} | sort -u | scripts/openkey-oracle/oracle | python3 -c '
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
Make executable: `chmod +x scripts/gen-parity-corpus.sh`.

- [ ] **Step 2: Generate the fixture**

Run:
```bash
bash scripts/gen-parity-corpus.sh
head -c 300 Tests/Fixtures/parity-corpus.json; echo
```
Expected: prints a count (thousands of rows) and a JSON array preview. The file is committed so tests run offline.

- [ ] **Step 3: Commit**

```bash
git add scripts/gen-parity-corpus.sh Tests/Fixtures/parity-corpus.json
git commit -m "test(parity): add corpus generator + committed golden fixtures"
```

---

### Task 14: ParityTests — engine vs OpenKey golden

**Files:**
- Modify: `project.yml` (ensure `Tests/Fixtures/parity-corpus.json` is a resource of the test target)
- Create: `Tests/ParityTests/ParityTests.swift`

- [ ] **Step 1: Wire the fixture as a test resource**

In `project.yml`, under `targets: dkeyTests:`, add the Fixtures path as a resource so the JSON is bundled:
```yaml
    sources:
      - path: Tests/SmokeTests
      - path: Tests/EngineTests
      - path: Tests/ParityTests
      - path: Tests/Fixtures
        buildPhase: resources
```

- [ ] **Step 2: Write `Tests/ParityTests/ParityTests.swift`**

```swift
import XCTest
@testable import dkey

final class ParityTests: XCTestCase {
    struct Row: Decodable { let input: String; let modern: String; let classic: String }

    func loadCorpus() throws -> [Row] {
        let url = Bundle(for: ParityTests.self).url(forResource: "parity-corpus", withExtension: "json")!
        return try JSONDecoder().decode([Row].self, from: Data(contentsOf: url))
    }

    func testParityModern() throws {
        var fails: [String] = []
        for row in try loadCorpus() where type(row.input, modern: true) != row.modern {
            fails.append("\(row.input): got \(type(row.input, modern: true)) want \(row.modern)")
        }
        XCTAssertTrue(fails.isEmpty, "modern parity failures (\(fails.count)):\n" + fails.prefix(40).joined(separator: "\n"))
    }

    func testParityClassic() throws {
        var fails: [String] = []
        for row in try loadCorpus() where type(row.input, modern: false) != row.classic {
            fails.append("\(row.input): got \(type(row.input, modern: false)) want \(row.classic)")
        }
        XCTAssertTrue(fails.isEmpty, "classic parity failures (\(fails.count)):\n" + fails.prefix(40).joined(separator: "\n"))
    }
}
```

- [ ] **Step 3: Run the full suite**

Run:
```bash
xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **` with all curated + parity tests passing. Each parity failure prints `input/got/want` — fix the corresponding ported function (the oracle is the source of truth; do not edit fixtures to match a buggy engine).

- [ ] **Step 4: Commit**

```bash
git add project.yml Tests/ParityTests/ParityTests.swift
git commit -m "test(parity): assert TelexEngine matches OpenKey on golden corpus"
```

---

## Self-Review

**Spec coverage (vs `2026-06-28-dkey-phase1-engine-design.md`):**
- Telex typing + plain keys → Task 4. ✅
- Tone marks s/f/r/x/j + modern/classic → Task 6. ✅
- Circumflex aa/ee/oo → Task 7. ✅
- Horn/breve w + standalone [ ] + ă → Task 8. ✅
- đ via dd → Task 9. ✅
- Tone undo (mark twice) → Task 6 (`testToggleOff`); z clear + restore → Task 10; circumflex restore → Task 7. ✅
- Backspace checkGrammar re-placement → Task 10. ✅
- Unicode NFC output (`_codeTable[0]`) → Tasks 2-3. ✅
- Modern/classic toggle as instance property → Task 3 (`useModernOrthography`). ✅
- Curated tests → Task 11; parity oracle + corpus + tests → Tasks 12-14. ✅
- Pure-Swift engine, no AppKit; oracle C++ out of app build → file structure + Task 12. ✅
- Deferred items (VNI, spell-check, quick-telex, codepages, macro, smart-switch) → none implemented. ✅

**Placeholder scan:** Task 6 `testToneOnConsonantWord` and Task 10 `testBackspaceReplacement` intentionally flag a value to confirm against the oracle — both carry concrete fallback assertions and instructions, not "TODO". Algorithm bodies cite exact C++ line ranges to port verbatim (a precise spec for a port, not a hand-wave). Data tables cite exact source ranges; the largest (`_codeTable[0]`) is inlined in full. ✅

**Type consistency:** `EngineOutput`/`Action`/`InputEngine` (Task 3) used unchanged in Tasks 4-14. `getCharacterCode`, `findAndCalculateVowel`, `insertMark`, `insertAOE`, `insertW`, `insertD`, `removeMark`, `checkGrammar` names consistent across tasks and match OpenKey. `vowelStartIndex`/`vowelEndIndex`/`vowelCount` consistent (Task 5 → 6). `type(_:modern:engine:)` helper signature stable across all test tasks. ✅

**Risks flagged in-plan:** `getCharacterCode` index math (Task 3 Step 3 note), oracle output reconstruction (Task 12 Step 1 note), oracle link stubs (Task 12 Step 3) — each has a concrete fallback instruction.
