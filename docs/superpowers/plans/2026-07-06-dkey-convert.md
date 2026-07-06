# Chuyển mã (Convert tool) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An in-app tool that converts a block of Vietnamese text between code tables (Unicode / TCVN3 / VNI-Windows / Unicode-Compound / CP1258), with case modes and remove-diacritics.

**Architecture:** A pure `ConvertTool.convert(...)` function (faithful port of OpenKey `ConvertTool.cpp`) drives off code-table data ported from `_codeTable[1..4]`; a `ConvertView` renders it and updates the result live. An oracle-generated parity corpus proves byte-for-byte agreement with OpenKey. No touch to the live typing engine.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit (macOS 14), XCTest, XcodeGen; C++ oracle for parity. Reference (GPL v3): `../mkey/Sources/Engine/{ConvertTool.cpp,Vietnamese.cpp}`.

## Global Constraints

- `Sources/Engine/` stays pure Swift (no AppKit/SwiftUI). `ConvertTool.convert` is a pure `String -> String` function.
- Code tables are ported verbatim from `../mkey/Sources/Engine/Vietnamese.cpp:430-490` (`_codeTable[1..4]`) + `_unicodeCompoundMark`; table `[0]` (Unicode) reuses the existing `codeTableUnicode`.
- The convert algorithm is a faithful port of `../mkey/Sources/Engine/ConvertTool.cpp:convertUtil` — **the oracle-generated corpus is the correctness authority** for exact byte values; when a parity row diverges, fix the port to match OpenKey, never weaken the test.
- Code-table index order (must match the `CodeTable` enum raw values): `0 unicode, 1 tcvn3, 2 vniWindows, 3 unicodeCompound, 4 cp1258`.
- No regression: the live engine is untouched; all prior tests (83 on `main`) stay green.
- XcodeGen: run `xcodegen generate` after adding any new source/test/fixture file. `dkey.xcodeproj` is gitignored — never commit it.
- Deployment macOS 14.0, Swift 5.9. Work on `feature/convert` (already created), commit after each task.

---

## File Structure

- `Sources/Engine/CodeTable.swift` *(new)* — `enum CodeTable` + the 5 code tables (data) + `unicodeCompoundMark`.
- `Sources/Engine/ConvertTool.swift` *(new)* — `enum CaseMode` + pure `convert(...)`.
- `Sources/App/Views/ConvertView.swift` *(new)* — the Chuyển mã tab UI.
- `Sources/App/Views/SettingsRootView.swift` *(modify)* — route `.convert` → `ConvertView()`.
- `scripts/openkey-oracle/convert-oracle.cpp` *(new)* + `scripts/gen-convert-corpus.sh` *(new)* — parity oracle + generator.
- `Tests/Fixtures/convert-corpus.json` *(new, committed)*.
- `Tests/ConvertTests/ConvertToolTests.swift` + `ConvertParityTests.swift` *(new)*.
- `project.yml` *(modify)* — add `Tests/ConvertTests` to `dkeyTests` sources.

---

## Task 1: CodeTable data

Ports the 4 legacy code tables + the compound-mark array. Table `[0]` reuses the existing `codeTableUnicode`.

**Files:**
- Create: `Sources/Engine/CodeTable.swift`
- Test: `Tests/ConvertTests/CodeTableTests.swift`
- Modify: `project.yml` (add `Tests/ConvertTests`)

**Interfaces:**
- Produces: `enum CodeTable: Int, CaseIterable { case unicode=0, tcvn3, vniWindows, unicodeCompound, cp1258 }` with `var displayName: String`; `static func table(_ t: CodeTable) -> [UInt32: [UInt16]]`; `let unicodeCompoundMark: [UInt16]` (5 combining marks, order sắc/huyền/hỏi/ngã/nặng).

- [ ] **Step 1: Add the test dir to project.yml**

In `project.yml`, under `dkeyTests: sources:`, add `- path: Tests/ConvertTests`. Then `xcodegen generate`.

- [ ] **Step 2: Write the failing data-integrity test**

Create `Tests/ConvertTests/CodeTableTests.swift`:

```swift
import XCTest
@testable import dkey

final class CodeTableTests: XCTestCase {
    func testAllFiveTablesPresent() {
        XCTAssertEqual(CodeTable.allCases.count, 5)
        for t in CodeTable.allCases {
            XCTAssertFalse(CodeTable.table(t).isEmpty, "\(t) table empty")
        }
    }

    func testUnicodeTableIsExistingCodeTable() {
        // Table [0] reuses codeTableUnicode: 'a' row starts with Â/â precomposed.
        XCTAssertEqual(CodeTable.table(.unicode)[UInt32(KeyCode.a)]?.first, 0x00C2)
    }

    func testTCVN3KnownBytes() {
        // TCVN3 'a' row first entries (Vietnamese.cpp:431): Â=0xA2, â=0xA9.
        let row = CodeTable.table(.tcvn3)[UInt32(KeyCode.a)]
        XCTAssertEqual(row?[0], 0xA2)
        XCTAssertEqual(row?[1], 0xA9)
    }

    func testCompoundMarkCount() {
        XCTAssertEqual(unicodeCompoundMark.count, 5)
        XCTAssertEqual(unicodeCompoundMark[0], 0x0301) // sắc
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `cd /Users/dat.nguyenmanh/Desktop/dat/my-git/dkey && xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: compile failure — `CodeTable` / `unicodeCompoundMark` undefined.

- [ ] **Step 4: Implement `CodeTable.swift`**

Create `Sources/Engine/CodeTable.swift`. Port the 4 legacy tables **verbatim** from `../mkey/Sources/Engine/Vietnamese.cpp:430-490` (each `{ KEY_X, {..hex..} }` row → `UInt32(KeyCode.x): [..hex..]`, with `KEY_X|TONE_MASK` → `UInt32(KeyCode.x) | EngineMask.tone`, `|TONEW_MASK` → `| EngineMask.toneW`). Skeleton + the first table's structure (fill the remaining rows from the reference — the Task 3 parity corpus catches any transcription slip):

```swift
import Foundation

public enum CodeTable: Int, CaseIterable {
    case unicode = 0, tcvn3, vniWindows, unicodeCompound, cp1258

    public var displayName: String {
        switch self {
        case .unicode:         return "Unicode"
        case .tcvn3:           return "TCVN3 (ABC)"
        case .vniWindows:      return "VNI Windows"
        case .unicodeCompound: return "Unicode tổ hợp"
        case .cp1258:          return "CP 1258"
        }
    }

    public static func table(_ t: CodeTable) -> [UInt32: [UInt16]] {
        switch t {
        case .unicode:         return codeTableUnicode           // existing (Vietnamese.cpp _codeTable[0])
        case .tcvn3:           return codeTableTCVN3
        case .vniWindows:      return codeTableVNIWindows
        case .unicodeCompound: return codeTableUnicodeCompound
        case .cp1258:          return codeTableCP1258
        }
    }
}

/// sắc, huyền, hỏi, ngã, nặng — Vietnamese.cpp _unicodeCompoundMark.
let unicodeCompoundMark: [UInt16] = [0x0301, 0x0300, 0x0309, 0x0303, 0x0323]

// TCVN3 (ABC) — verbatim port of _codeTable[1] (Vietnamese.cpp:430-443).
let codeTableTCVN3: [UInt32: [UInt16]] = [
    UInt32(KeyCode.a): [0xA2,0xA9,0xA1,0xA8,0xB8,0xB8,0xB5,0xB5,0xB6,0xB6,0xB7,0xB7,0xB9,0xB9],
    UInt32(KeyCode.o): [0xA4,0xAB,0xA5,0xAC,0xE3,0xE3,0xDF,0xDF,0xE1,0xE1,0xE2,0xE2,0xE4,0xE4],
    UInt32(KeyCode.u): [0x00,0x00,0xA6,0xAD,0xF3,0xF3,0xEF,0xEF,0xF1,0xF1,0xF2,0xF2,0xF4,0xF4],
    UInt32(KeyCode.e): [0xA3,0xAA,0x00,0x00,0xD0,0xD0,0xCC,0xCC,0xCE,0xCE,0xCF,0xCF,0xD1,0xD1],
    UInt32(KeyCode.d): [0xA7,0xAE],
    UInt32(KeyCode.a) | EngineMask.tone:  [0xCA,0xCA,0xC7,0xC7,0xC8,0xC8,0xC9,0xC9,0xCB,0xCB],
    UInt32(KeyCode.a) | EngineMask.toneW: [0xBE,0xBE,0xBB,0xBB,0xBC,0xBC,0xBD,0xBD,0xC6,0xC6],
    UInt32(KeyCode.o) | EngineMask.tone:  [0xE8,0xE8,0xE5,0xE5,0xE6,0xE6,0xE7,0xE7,0xE9,0xE9],
    UInt32(KeyCode.o) | EngineMask.toneW: [0xED,0xED,0xEA,0xEA,0xEB,0xEB,0xEC,0xEC,0xEE,0xEE],
    UInt32(KeyCode.u) | EngineMask.toneW: [0xF8,0xF8,0xF5,0xF5,0xF6,0xF6,0xF7,0xF7,0xF9,0xF9],
    UInt32(KeyCode.e) | EngineMask.tone:  [0xD5,0xD5,0xD2,0xD2,0xD3,0xD3,0xD4,0xD4,0xD6,0xD6],
    UInt32(KeyCode.i): [0xDD,0xDD,0xD7,0xD7,0xD8,0xD8,0xDC,0xDC,0xDE,0xDE],
    UInt32(KeyCode.y): [0xFD,0xFD,0xFA,0xFA,0xFB,0xFB,0xFC,0xFC,0xFE,0xFE],
]

// VNI Windows — verbatim port of _codeTable[2] (Vietnamese.cpp:444-457).
let codeTableVNIWindows: [UInt32: [UInt16]] = [ /* port all rows from the reference */ ]

// Unicode tổ hợp — verbatim port of _codeTable[3] (Vietnamese.cpp:458-471).
let codeTableUnicodeCompound: [UInt32: [UInt16]] = [ /* port all rows from the reference */ ]

// CP 1258 — verbatim port of _codeTable[4] (Vietnamese.cpp:472-485).
let codeTableCP1258: [UInt32: [UInt16]] = [ /* port all rows from the reference */ ]
```

Fill the three `/* port all rows */` dictionaries verbatim from the reference lines cited. Note `0xDc`/`0xDe` in the reference are hex (case-insensitive) → write `0xDC`/`0xDE`.

- [ ] **Step 5: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: `TEST SUCCEEDED` — CodeTableTests pass, prior tests green.

- [ ] **Step 6: Commit**

```bash
git add project.yml Sources/Engine/CodeTable.swift Tests/ConvertTests/CodeTableTests.swift
git commit -m "feat(engine): port TCVN3/VNI-Win/Compound/CP1258 code tables"
```

---

## Task 2: ConvertTool.convert (pure algorithm)

Faithful port of `ConvertTool.cpp:convertUtil`.

**Files:**
- Create: `Sources/Engine/ConvertTool.swift`
- Test: `Tests/ConvertTests/ConvertToolTests.swift`

**Interfaces:**
- Consumes: `CodeTable.table(_:)`, `unicodeCompoundMark`, `keyCodeToCharacter(_:)` (existing in `VietnameseTables.swift`), `EngineMask`.
- Produces: `enum CaseMode: Int, CaseIterable { case keep=0, upper, lower, sentence, title }`; `enum ConvertTool { static func convert(_ text: String, from: CodeTable, to: CodeTable, caseMode: CaseMode = .keep, removeMark: Bool = false) -> String }`.

- [ ] **Step 1: Write the failing curated tests** (self-verifiable — no external golden needed)

Create `Tests/ConvertTests/ConvertToolTests.swift`:

```swift
import XCTest
@testable import dkey

final class ConvertToolTests: XCTestCase {
    private func roundTrip(_ s: String, via t: CodeTable) -> String {
        let enc = ConvertTool.convert(s, from: .unicode, to: t)
        return ConvertTool.convert(enc, from: t, to: .unicode)
    }

    func testRoundTripAllTables() {
        let s = "Tiếng Việt thân thương"
        for t: CodeTable in [.tcvn3, .vniWindows, .unicodeCompound, .cp1258] {
            XCTAssertEqual(roundTrip(s, via: t), s, "round-trip via \(t) failed")
        }
    }

    func testNonVietnamesePassthrough() {
        XCTAssertEqual(ConvertTool.convert("abc 123 @#", from: .unicode, to: .tcvn3), "abc 123 @#")
    }

    func testCaseUpper() {
        XCTAssertEqual(ConvertTool.convert("tiếng việt", from: .unicode, to: .unicode, caseMode: .upper), "TIẾNG VIỆT")
    }

    func testCaseLower() {
        XCTAssertEqual(ConvertTool.convert("TIẾNG VIỆT", from: .unicode, to: .unicode, caseMode: .lower), "tiếng việt")
    }

    func testRemoveMark() {
        XCTAssertEqual(ConvertTool.convert("tiếng Việt", from: .unicode, to: .unicode, removeMark: true), "tieng Viet")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: compile failure — `ConvertTool` / `CaseMode` undefined.

- [ ] **Step 3: Implement `ConvertTool.swift`**

Create `Sources/Engine/ConvertTool.swift` — faithful port of `ConvertTool.cpp:convertUtil` (structure below; the per-target byte emit mirrors C++ lines 107-123, the caps k±1 logic lines 91-95, remove-mark lines 98-105, break-state lines 164-174). Work at the `Unicode.Scalar` level so non-BMP passthrough chars are preserved.

```swift
import Foundation

public enum CaseMode: Int, CaseIterable { case keep = 0, upper, lower, sentence, title }

public enum ConvertTool {
    private static let breakChars: Set<UInt32> = [46, 63, 33] // . ? !

    /// Index (i+1)<<13 marker for a compound combining mark, else nil (ConvertTool.cpp:42-49).
    private static func compoundMarkMarker(_ s: Unicode.Scalar) -> UInt16? {
        guard let i = unicodeCompoundMark.firstIndex(of: UInt16(truncatingIfNeeded: s.value)) else { return nil }
        return UInt16((i + 1) << 13)
    }

    private static func findKeyCode(_ value: UInt16, in table: [UInt32: [UInt16]]) -> (j: UInt32, k: Int)? {
        for (key, vals) in table {
            if let k = vals.firstIndex(of: value) { return (key, k) }
        }
        return nil
    }

    public static func convert(_ text: String, from: CodeTable, to: CodeTable,
                               caseMode: CaseMode = .keep, removeMark: Bool = false) -> String {
        let src = CodeTable.table(from)
        let dst = CodeTable.table(to)
        let scalars = Array(text.unicodeScalars)
        var out: [Unicode.Scalar] = []
        let allCaps = caseMode == .upper, allNon = caseMode == .lower
        var shouldUpper = caseMode == .sentence || caseMode == .title
        var hasBreak = false
        var i = 0

        // Map a matched (j,k) to the target-table output scalars.
        func emit(_ j: UInt32, _ k0: Int) {
            var k = k0
            if (allCaps || shouldUpper) && k % 2 != 0 { k -= 1 }
            else if (allNon || !shouldUpper) && k % 2 == 0 { k += 1 }
            var target = dst[j]?[k] ?? 0
            if removeMark {
                var ch = keyCodeToCharacter(j)               // ASCII base letter
                if allCaps { ch = UInt16(Character(Unicode.Scalar(UInt8(ch))).uppercased().unicodeScalars.first!.value) }
                else if allNon { ch = UInt16(Character(Unicode.Scalar(UInt8(ch))).lowercased().unicodeScalars.first!.value) }
                out.append(Unicode.Scalar(ch) ?? " ")
                return
            }
            switch to {
            case .unicode, .tcvn3:
                out.append(Unicode.Scalar(target) ?? " ")
            case .vniWindows, .cp1258:
                out.append(Unicode.Scalar(UInt8(target & 0xFF)))         // low byte
                if (target >> 8) > 32 { out.append(Unicode.Scalar(UInt8(target >> 8))) } // high byte
            case .unicodeCompound:
                if (target >> 13) > 0 {
                    out.append(Unicode.Scalar(target & 0x1FFF) ?? " ")
                    out.append(Unicode.Scalar(unicodeCompoundMark[Int((target >> 13) - 1)]) ?? " ")
                } else {
                    out.append(Unicode.Scalar(target) ?? " ")
                }
            }
        }

        while i < scalars.count {
            let cur = scalars[i]
            // Two-unit / compound source detection (ConvertTool.cpp:66-86).
            if i < scalars.count - 1 {
                var t: UInt16? = nil, consume2 = false
                switch from {
                case .vniWindows, .cp1258:
                    t = UInt16(truncatingIfNeeded: cur.value) | (UInt16(truncatingIfNeeded: scalars[i+1].value) << 8); consume2 = true
                case .unicodeCompound:
                    if let m = compoundMarkMarker(scalars[i+1]) { t = UInt16(truncatingIfNeeded: cur.value) | m; consume2 = true }
                default: break
                }
                if let t, let (j, k) = findKeyCode(t, in: src) {
                    emit(j, k); i += consume2 ? 2 : 1; shouldUpper = false; hasBreak = false; continue
                }
            }
            // Single-unit source (ConvertTool.cpp:130-154).
            if let (j, k) = findKeyCode(UInt16(truncatingIfNeeded: cur.value), in: src) {
                emit(j, k); i += 1; shouldUpper = false; hasBreak = false; continue
            }
            // Passthrough — preserve the original scalar, apply case (ConvertTool.cpp:156-174).
            if allCaps || shouldUpper { out.append(contentsOf: String(cur).uppercased().unicodeScalars) }
            else if allNon || !shouldUpper { out.append(contentsOf: String(cur).lowercased().unicodeScalars) }
            else { out.append(cur) }

            let v = cur.value
            if v == 10 || (hasBreak && v == 32) { if caseMode == .sentence || caseMode == .title { shouldUpper = true } }
            else if v == 32 && caseMode == .title { shouldUpper = true }
            else if breakChars.contains(v) { hasBreak = true }
            else { shouldUpper = false; hasBreak = false }
            i += 1
        }
        return String(String.UnicodeScalarView(out))
    }
}
```

Note: this is the port's best effort; **Task 3's parity corpus is the byte-level gate.** If a curated round-trip fails, debug against `ConvertTool.cpp` (the caps/emit branches are the usual suspects) — do not change expected values.

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: `TEST SUCCEEDED`. If a round-trip case fails, fix the port to match `ConvertTool.cpp`, re-run.

- [ ] **Step 5: Commit**

```bash
git add Sources/Engine/ConvertTool.swift Tests/ConvertTests/ConvertToolTests.swift
git commit -m "feat(engine): ConvertTool text encoding conversion"
```

---

## Task 3: Convert oracle + parity corpus

Byte-for-byte validation against OpenKey's real `ConvertTool`.

**Files:**
- Create: `scripts/openkey-oracle/convert-oracle.cpp`, `scripts/gen-convert-corpus.sh`
- Create: `Tests/Fixtures/convert-corpus.json`
- Create: `Tests/ConvertTests/ConvertParityTests.swift`

**Interfaces:**
- Consumes: `ConvertTool.convert(_:from:to:caseMode:removeMark:)`.
- Produces: `Tests/Fixtures/convert-corpus.json` — array of `{text, from, to, expected}` (from/to are `CodeTable` raw ints; caseMode=keep, removeMark=false).

- [ ] **Step 1: Write the convert oracle**

Create `scripts/openkey-oracle/convert-oracle.cpp`: compile OpenKey's `ConvertTool.cpp` + engine data; read stdin lines `<from>\t<to>\t<utf8-text>`; for each, set globals `convertToolFromCode`/`convertToolToCode` (case/remove off), call `convertUtil(text)`, print `<from>\t<to>\t<text>\t<result>` (result UTF-8). Mirror the include/stub setup of the existing `scripts/openkey-oracle/oracle.cpp` (reuse its `build.sh` pattern — extend it to also build this target).

- [ ] **Step 2: Write the corpus generator**

Create `scripts/gen-convert-corpus.sh` (mirror `gen-parity-corpus-vni.sh`): a Vietnamese wordlist (reuse the syllable combinations already used for the VNI corpus, converted to Unicode text) piped with each `(from,to)` pair where from=0 (Unicode) to each of {1,2,3,4} and the reverse, through `convert-oracle`, into `Tests/Fixtures/convert-corpus.json`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/openkey-oracle/build.sh   # builds convert-oracle too
WORDS=$(cat Tests/Fixtures/vietnamese-words.txt 2>/dev/null || printf 'Tiếng\nViệt\nđồng\nxin chào\nngôn ngữ\nphát triển\n')
OUT=Tests/Fixtures/convert-corpus.json
{
  while IFS= read -r w; do
    for pair in "0 1" "1 0" "0 2" "2 0" "0 3" "3 0" "0 4" "4 0"; do
      set -- $pair; printf '%s\t%s\t%s\n' "$1" "$2" "$w"
    done
  done <<< "$WORDS"
} | scripts/openkey-oracle/convert-oracle | python3 -c '
import sys, json
rows=[]
for line in sys.stdin:
    p=line.rstrip("\n").split("\t")
    if len(p)!=4: continue
    rows.append({"from":int(p[0]),"to":int(p[1]),"text":p[2],"expected":p[3]})
json.dump(rows, open("'"$OUT"'","w"), ensure_ascii=False, indent=0)
print(f"wrote {len(rows)} rows to '"$OUT"'")
'
```

- [ ] **Step 3: Generate the corpus**

Run: `bash scripts/gen-convert-corpus.sh`
Expected: `wrote <N> rows to Tests/Fixtures/convert-corpus.json`; file exists.

- [ ] **Step 4: Write the parity test**

Create `Tests/ConvertTests/ConvertParityTests.swift`:

```swift
import XCTest
@testable import dkey

final class ConvertParityTests: XCTestCase {
    struct Row: Decodable { let from: Int; let to: Int; let text: String; let expected: String }

    func testConvertParity() throws {
        let url = Bundle(for: ConvertParityTests.self).url(forResource: "convert-corpus", withExtension: "json")!
        let rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: url))
        var fails: [String] = []
        for r in rows {
            let got = ConvertTool.convert(r.text, from: CodeTable(rawValue: r.from)!, to: CodeTable(rawValue: r.to)!)
            if got != r.expected { fails.append("\(r.text) \(r.from)->\(r.to): got \(got) want \(r.expected)") }
        }
        XCTAssertTrue(fails.isEmpty, "convert parity failures (\(fails.count)):\n" + fails.prefix(40).joined(separator: "\n"))
    }
}
```

- [ ] **Step 5: Run — regenerate not needed after engine fixes**

Run: `xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -15`
Expected: `TEST SUCCEEDED`. If parity fails, the `got/want` lines pinpoint port bugs in Task 2's `convert` (or Task 1 data) — fix to match the oracle, re-run (corpus is golden, do not regenerate to "fix").

- [ ] **Step 6: Commit**

```bash
git add scripts/openkey-oracle/convert-oracle.cpp scripts/gen-convert-corpus.sh Tests/Fixtures/convert-corpus.json Tests/ConvertTests/ConvertParityTests.swift
git commit -m "test(engine): convert parity corpus from OpenKey oracle"
```

---

## Task 4: ConvertView + tab wiring

**Files:**
- Create: `Sources/App/Views/ConvertView.swift`
- Modify: `Sources/App/Views/SettingsRootView.swift`

**Interfaces:**
- Consumes: `CodeTable`, `CaseMode`, `ConvertTool.convert(...)`.

- [ ] **Step 1: Build the view**

Create `Sources/App/Views/ConvertView.swift`:

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
        Form {
            HStack {
                Picker("Từ bảng mã:", selection: $fromRaw) {
                    ForEach(CodeTable.allCases, id: \.rawValue) { Text($0.displayName).tag($0.rawValue) }
                }
                Button { let t = fromRaw; fromRaw = toRaw; toRaw = t } label: { Image(systemName: "arrow.left.arrow.right") }
                Picker("Sang:", selection: $toRaw) {
                    ForEach(CodeTable.allCases, id: \.rawValue) { Text($0.displayName).tag($0.rawValue) }
                }
            }
            Picker("Kiểu chữ:", selection: $caseRaw) {
                Text("Giữ nguyên").tag(CaseMode.keep.rawValue)
                Text("IN HOA TOÀN BỘ").tag(CaseMode.upper.rawValue)
                Text("in thường toàn bộ").tag(CaseMode.lower.rawValue)
                Text("Hoa đầu câu").tag(CaseMode.sentence.rawValue)
                Text("Hoa Mỗi Đầu Từ").tag(CaseMode.title.rawValue)
            }
            Toggle("Loại bỏ dấu thanh (tiếng Việt → khong dau)", isOn: $removeMark)
            Section("Văn bản") {
                TextEditor(text: $input).frame(minHeight: 90).font(.body)
            }
            Section("Kết quả") {
                TextEditor(text: .constant(output)).frame(minHeight: 90).font(.body)
                Button("Copy kết quả") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                }
            }
        }
        .formStyle(.grouped)
    }
}
```

- [ ] **Step 2: Route the `.convert` tab**

In `Sources/App/Views/SettingsRootView.swift`, add to the `switch`:

```swift
                case .convert: ConvertView()
```
(keep `.typing`, `.about`, and the `default` placeholder).

- [ ] **Step 3: Regenerate + build**

Run: `xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug build 2>&1 | tail -8`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Full test pass (regression gate)**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -8`
Expected: `TEST SUCCEEDED` — all convert + prior tests green.

- [ ] **Step 5: Manual smoke (deferred to user)**

Open Cài đặt → Chuyển mã. Type/paste Vietnamese Unicode text; switch "Sang" to TCVN3 / VNI Windows → result updates live; try case modes + remove-mark; "Copy kết quả" copies the result. Choices persist across relaunch.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/Views/ConvertView.swift Sources/App/Views/SettingsRootView.swift
git commit -m "feat(app): Chuyển mã (encoding converter) tab"
```

---

## Self-Review

**1. Spec coverage:**
- 5 code tables ported → Task 1. ✅
- Convert algorithm (5 case modes + remove-mark + packed-byte decode) → Task 2. ✅
- Oracle-backed parity → Task 3. ✅
- In-app UI (from/to + swap, case, remove-mark, live output, copy, @AppStorage) → Task 4. ✅
- Route `.convert`, others unchanged → Task 4 Step 2. ✅
- No engine hot-path change / no regression → every task's test step. ✅
- Live-encoding (`vCodeTable`) explicitly out → not in any task. ✅

**2. Placeholder scan:** The three legacy-table dictionaries in Task 1 are marked "port verbatim from Vietnamese.cpp:<lines>" rather than transcribed — a deliberate verbatim data port from an available reference, guarded by the Task 3 parity corpus (transcribing 40+ hex rows by hand is more error-prone than citing the source). TCVN3 is given in full as the pattern. Everything else is complete code.

**3. Type consistency:** `CodeTable` (Task 1) is used identically in `ConvertTool.convert` (Task 2), the parity test (Task 3), and `ConvertView` (Task 4). `CaseMode` (Task 2) matches its use in Task 4. `ConvertTool.convert(_:from:to:caseMode:removeMark:)` signature is identical across Tasks 2–4. `keyCodeToCharacter`/`codeTableUnicode`/`EngineMask` are pre-existing symbols. ✅
