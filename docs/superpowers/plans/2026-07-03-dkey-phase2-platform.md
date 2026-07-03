# dkey Phase 2 — Platform Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the Phase-1 Telex engine to real macOS typing via a `CGEventTap` that intercepts keystrokes, runs them through the engine, and synthesizes backspaces + Unicode output — with a ⌥Z toggle, Accessibility permission flow, event-tap auto-recovery, and sleep/wake re-arm.

**Architecture:** Clean Swift wrapper over CoreGraphics (Hướng B). All decision logic lives in a pure, unit-tested `InputController` (`KeyEvent → SynthesisPlan`, no CGEvent). Thin adapters (`KeySynthesizer`, `EventTap`, `PermissionMonitor`) do the CGEvent/AX I/O and are verified by build + a manual smoke script. Interception model is consume-and-resynthesize, driven by the Phase-1 `EngineOutput.action` contract.

**Tech Stack:** Swift 5.9 / macOS 14, CoreGraphics (CGEventTap, CGEventCreateKeyboardEvent, CGEventKeyboardSetUnicodeString), ApplicationServices (AXIsProcessTrusted), AppKit (NSWorkspace sleep/wake), XCTest, XcodeGen/xcodebuild.

## Global Constraints

- Swift language version **5.9**, deployment target **macOS 14.0**.
- `Sources/Platform/` and `Sources/Engine/` are **pure Swift** — no ObjC++/bridging header. CoreGraphics/AppKit are Swift-importable frameworks (allowed).
- Consume `Sources/Engine` API only: `TelexEngine()`, `handle(key: UInt16, caps: Bool) -> EngineOutput`, `newSession()`, `backspace()`, `useModernOrthography`. `EngineOutput{backspaceCount:Int, newChars:[Unicode.Scalar], action:Action}`, `Action ∈ {passthrough, process, wordBreak, restore}`.
- `action` → tap mapping (verbatim contract): `.passthrough`/`.wordBreak` → let the OS type the key (do NOT synthesize); `.process`/`.restore` → consume the key + synthesize `backspaceCount` backspaces then `newChars`.
- Switch hotkey default is `AppState.defaultSwitchKeyStatus = 0x7A000206` (⌥Z): low byte `0x06 = KEY_Z`, bit `0x200` = option. Bitfield: keycode=`status & 0xFF`, control=`0x100`, option=`0x200`, command=`0x400`, shift=`0x800`.
- Backspace keycode is **51**; unicode-injection uses keycode **0** + `CGEventKeyboardSetUnicodeString`.
- Synthesized events use a **private `CGEventSource`**; the tap filters its own events by comparing `CGEventGetIntegerValueField(event, .eventSourceStateID)` to the source's state id.
- DEFERRED (do NOT implement): AX slow-path (Spotlight/Raycast), per-app/browser workarounds, smart-switch, login-item/SMAppService, settings persistence, hotkey-rebind UI, VNI/codepages/macro.
- Commit after each task with the message shown in its final step.
- Build/test command (the `rm -rf build` avoids a stale-DerivedData "entitlements modified during build" false error): `xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -8`

---

## File Structure

Created under `Sources/Platform/` (pure Swift):
- `KeyEvent.swift` — value type describing one keyboard event (no CGEvent).
- `SynthesisPlan.swift` — the decision result enum.
- `HotkeyMatcher.swift` — match `switchKeyStatus` bitfield vs keyCode+flags.
- `InputController.swift` — **the pure, unit-tested core**: `KeyEvent → SynthesisPlan`, owns `TelexEngine` + language state.
- `KeySynthesizer.swift` — CGEvent backspace + unicode synthesis (private source).
- `EventTap.swift` — CGEventTap creation, C-callback bridging, self-event filter, auto-recovery.
- `PermissionMonitor.swift` — Accessibility trust check + prompt + poll.

Modified (app glue):
- `Sources/App/AppState.swift` — hold the shared `InputController`; keep `isVietnamese` in sync.
- `Sources/App/DkeyApp.swift` — lifecycle: permission → start tap; NSWorkspace sleep/wake; menu toggle wiring.
- `project.yml` — add `Sources/Platform` to the `dkey` target; add `Tests/PlatformTests` to `dkeyTests`.

Tests / tooling:
- `Tests/PlatformTests/HotkeyMatcherTests.swift`, `Tests/PlatformTests/InputControllerTests.swift`.
- `scripts/verify-phase2.md` — manual smoke checklist.

**Testability boundary:** Tasks 1-3 (KeyEvent, SynthesisPlan, HotkeyMatcher, InputController) are pure and unit-tested via TDD. Tasks 4-7 (KeySynthesizer, EventTap, PermissionMonitor, app wiring) are CGEvent/AX I/O — they cannot be meaningfully unit-tested, so their verification is "compiles + the app builds + covered by the Task 8 smoke script." Do NOT write assert-nothing unit tests for them.

---

### Task 1: Platform target wiring + KeyEvent + SynthesisPlan

**Files:**
- Modify: `project.yml`
- Create: `Sources/Platform/KeyEvent.swift`
- Create: `Sources/Platform/SynthesisPlan.swift`
- Test: `Tests/PlatformTests/PlatformValueTypesTests.swift`

**Interfaces:**
- Produces: `struct KeyEvent { enum Kind {case keyDown,keyUp,flagsChanged}; let keyCode:UInt16; let caps:Bool; let hasOtherControl:Bool; let kind:Kind; let flags:UInt64 }`; `enum SynthesisPlan: Equatable { case passthrough; case toggleLanguage; case consume(backspaces:Int, chars:[Unicode.Scalar]) }`.

- [ ] **Step 1: Add Platform sources + PlatformTests to `project.yml`**

Under `targets: dkey: sources:` add `- path: Sources/Platform` (after `Sources/Engine`). Under `targets: dkeyTests: sources:` add `- path: Tests/PlatformTests`. Result for dkey:
```yaml
    sources:
      - path: Sources/App
      - path: Sources/Engine
      - path: Sources/Platform
      - path: Sources/Support
        includes:
          - "Assets.xcassets"
```
And for dkeyTests add the `Tests/PlatformTests` entry alongside the existing `Tests/SmokeTests`, `Tests/EngineTests`, `Tests/ParityTests`, `Tests/Fixtures` entries.

- [ ] **Step 2: Create `Sources/Platform/KeyEvent.swift`**

```swift
import Foundation

/// One keyboard event, decoupled from CGEvent so the decision logic is testable.
public struct KeyEvent: Equatable {
    public enum Kind { case keyDown, keyUp, flagsChanged }
    public let keyCode: UInt16      // macOS virtual key code (same space as Engine KeyCode)
    public let caps: Bool           // shift or caps-lock active
    public let hasOtherControl: Bool // control / command / option / fn held (shift excluded)
    public let kind: Kind
    public let flags: UInt64        // raw CGEventFlags rawValue, for hotkey matching
    public init(keyCode: UInt16, caps: Bool, hasOtherControl: Bool, kind: Kind, flags: UInt64) {
        self.keyCode = keyCode; self.caps = caps; self.hasOtherControl = hasOtherControl
        self.kind = kind; self.flags = flags
    }
}
```

- [ ] **Step 3: Create `Sources/Platform/SynthesisPlan.swift`**

```swift
import Foundation

/// What the event tap should do with a key, decided by InputController.
public enum SynthesisPlan: Equatable {
    case passthrough                                   // let the OS type the key
    case toggleLanguage                                // ⌥Z pressed; consume, flip VI/EN (already applied)
    case consume(backspaces: Int, chars: [Unicode.Scalar]) // consume; delete then insert
}
```

- [ ] **Step 4: Write failing test `Tests/PlatformTests/PlatformValueTypesTests.swift`**

```swift
import XCTest
@testable import dkey

final class PlatformValueTypesTests: XCTestCase {
    func testKeyEventEquatable() {
        let a = KeyEvent(keyCode: 1, caps: false, hasOtherControl: false, kind: .keyDown, flags: 0)
        let b = KeyEvent(keyCode: 1, caps: false, hasOtherControl: false, kind: .keyDown, flags: 0)
        XCTAssertEqual(a, b)
    }
    func testSynthesisPlanEquatable() {
        XCTAssertEqual(SynthesisPlan.consume(backspaces: 1, chars: ["á"]),
                       SynthesisPlan.consume(backspaces: 1, chars: ["á"]))
        XCTAssertNotEqual(SynthesisPlan.passthrough, SynthesisPlan.toggleLanguage)
    }
}
```

- [ ] **Step 5: Generate, build, run — verify pass**

Run: `xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -8`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add project.yml Sources/Platform/KeyEvent.swift Sources/Platform/SynthesisPlan.swift Tests/PlatformTests/PlatformValueTypesTests.swift
git commit -m "feat(platform): add KeyEvent + SynthesisPlan value types, wire Platform target"
```

---

### Task 2: HotkeyMatcher

**Files:**
- Create: `Sources/Platform/HotkeyMatcher.swift`
- Test: `Tests/PlatformTests/HotkeyMatcherTests.swift`

**Interfaces:**
- Consumes: CGEventFlags raw values (passed as `UInt64`).
- Produces: `enum HotkeyMatcher { static func matches(status: Int32, keyCode: UInt16, flags: UInt64) -> Bool }`.

- [ ] **Step 1: Create `Sources/Platform/HotkeyMatcher.swift`**

Match the switch-key bitfield against the event. Modifier bits in `status`: control `0x100`, option `0x200`, command `0x400`, shift `0x800`. CGEventFlags masks: shift `0x20000`, control `0x40000`, option/alternate `0x80000`, command `0x100000`. Exact match (each required modifier present, and no mismatch) — mirrors OpenKey `checkHotKey` XOR logic.
```swift
import CoreGraphics

/// Matches the switch-key bitfield (e.g. ⌥Z = 0x7A000206) against a physical key event.
enum HotkeyMatcher {
    static func matches(status: Int32, keyCode: UInt16, flags: UInt64) -> Bool {
        let wantKey = UInt16(status & 0xFF)
        if wantKey == 0 || keyCode != wantKey { return false }
        let f = CGEventFlags(rawValue: flags)
        func need(_ bit: Int32, _ mask: CGEventFlags) -> Bool {
            (status & bit != 0) == f.contains(mask)   // required == present
        }
        return need(0x100, .maskControl)
            && need(0x200, .maskAlternate)
            && need(0x400, .maskCommand)
            && need(0x800, .maskShift)
    }
}
```

- [ ] **Step 2: Write failing test `Tests/PlatformTests/HotkeyMatcherTests.swift`**

```swift
import XCTest
import CoreGraphics
@testable import dkey

final class HotkeyMatcherTests: XCTestCase {
    let altZ: Int32 = 0x7A000206   // ⌥Z: keyCode 0x06 (KEY_Z), option bit 0x200
    let optionOnly = CGEventFlags.maskAlternate.rawValue

    func testMatchesAltZ() {
        XCTAssertTrue(HotkeyMatcher.matches(status: altZ, keyCode: 6, flags: optionOnly))
    }
    func testWrongKey() {
        XCTAssertFalse(HotkeyMatcher.matches(status: altZ, keyCode: 1, flags: optionOnly))
    }
    func testMissingOption() {
        XCTAssertFalse(HotkeyMatcher.matches(status: altZ, keyCode: 6, flags: 0))
    }
    func testExtraCommandRejected() {
        let optCmd = (CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue)
        XCTAssertFalse(HotkeyMatcher.matches(status: altZ, keyCode: 6, flags: optCmd))
    }
}
```

- [ ] **Step 3: Run, verify pass**

Run the Global-Constraints build/test command.
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Sources/Platform/HotkeyMatcher.swift Tests/PlatformTests/HotkeyMatcherTests.swift
git commit -m "feat(platform): add HotkeyMatcher (switch-key bitfield matching)"
```

---

### Task 3: InputController (pure decision core)

**Files:**
- Create: `Sources/Platform/InputController.swift`
- Test: `Tests/PlatformTests/InputControllerTests.swift`

**Interfaces:**
- Consumes: `TelexEngine`, `KeyEvent`, `SynthesisPlan`, `HotkeyMatcher`, `AppState.defaultSwitchKeyStatus`.
- Produces: `final class InputController { init(engine:TelexEngine, isVietnamese:Bool, switchKeyStatus:Int32); var isVietnamese:Bool; var switchKeyStatus:Int32; var onLanguageChanged:((Bool)->Void)?; func handle(_ e:KeyEvent) -> SynthesisPlan; func setVietnamese(_:Bool) }`.

- [ ] **Step 1: Create `Sources/Platform/InputController.swift`**

```swift
import Foundation

/// Pure decision core: turns a KeyEvent into a SynthesisPlan. No CGEvent here.
/// Owns the Telex engine and the language state; the app layer keeps AppState in sync
/// via `onLanguageChanged` and `setVietnamese`.
public final class InputController {
    public let engine: TelexEngine
    public var isVietnamese: Bool
    public var switchKeyStatus: Int32
    /// Called (on the same thread as handle) whenever the language flips via the hotkey.
    public var onLanguageChanged: ((Bool) -> Void)?

    public init(engine: TelexEngine = TelexEngine(),
                isVietnamese: Bool = true,
                switchKeyStatus: Int32 = 0x7A000206) {
        self.engine = engine
        self.isVietnamese = isVietnamese
        self.switchKeyStatus = switchKeyStatus
    }

    /// UI-driven language change (menu toggle). Resets the engine session.
    public func setVietnamese(_ on: Bool) {
        isVietnamese = on
        engine.newSession()
    }

    public func handle(_ e: KeyEvent) -> SynthesisPlan {
        switch e.kind {
        case .flagsChanged, .keyUp:
            return .passthrough
        case .keyDown:
            break
        }
        // 1. Hotkey first (so ⌥Z is caught before the other-control passthrough).
        if HotkeyMatcher.matches(status: switchKeyStatus, keyCode: e.keyCode, flags: e.flags) {
            isVietnamese.toggle()
            engine.newSession()
            onLanguageChanged?(isVietnamese)
            return .toggleLanguage
        }
        // 2. English mode: never transform.
        if !isVietnamese { return .passthrough }
        // 3. A control/command/option shortcut breaks the word and passes through.
        if e.hasOtherControl {
            engine.newSession()
            return .passthrough
        }
        // 4. Feed the engine; map the action contract to a plan.
        let out = engine.handle(key: e.keyCode, caps: e.caps)
        switch out.action {
        case .passthrough, .wordBreak:
            return .passthrough
        case .process, .restore:
            return .consume(backspaces: out.backspaceCount, chars: out.newChars)
        }
    }
}
```

- [ ] **Step 2: Write failing test `Tests/PlatformTests/InputControllerTests.swift`**

Helper: build KeyEvents from ASCII via `KeyCode.keyCode(for:)`.
```swift
import XCTest
import CoreGraphics
@testable import dkey

final class InputControllerTests: XCTestCase {
    private func keyDown(_ ch: Character, control: Bool = false, flags: UInt64 = 0) -> KeyEvent {
        let (code, caps) = KeyCode.keyCode(for: ch)!
        return KeyEvent(keyCode: code, caps: caps, hasOtherControl: control, kind: .keyDown, flags: flags)
    }

    func testVietnameseTransform() {
        let c = InputController()                       // VI on by default
        XCTAssertEqual(c.handle(keyDown("a")), .passthrough)          // plain letter → OS types it
        XCTAssertEqual(c.handle(keyDown("s")), .consume(backspaces: 1, chars: ["á"]))
    }
    func testWordBreakPassthrough() {
        let c = InputController()
        _ = c.handle(keyDown("a"))
        XCTAssertEqual(c.handle(keyDown(" ")), .passthrough)          // space → wordBreak → passthrough
    }
    func testHotkeyTogglesLanguage() {
        let c = InputController()
        var notified: Bool?
        c.onLanguageChanged = { notified = $0 }
        let z = KeyEvent(keyCode: 6, caps: false, hasOtherControl: true,
                         kind: .keyDown, flags: CGEventFlags.maskAlternate.rawValue)
        XCTAssertEqual(c.handle(z), .toggleLanguage)
        XCTAssertFalse(c.isVietnamese)
        XCTAssertEqual(notified, false)
    }
    func testEnglishModePassthrough() {
        let c = InputController(isVietnamese: false)
        XCTAssertEqual(c.handle(keyDown("a")), .passthrough)
        XCTAssertEqual(c.handle(keyDown("s")), .passthrough)          // no transform in EN
    }
    func testOtherControlPassthrough() {
        let c = InputController()
        _ = c.handle(keyDown("a"))
        XCTAssertEqual(c.handle(keyDown("c", control: true)), .passthrough) // ⌘C not transformed
    }
    func testFlagsChangedAndKeyUpPassthrough() {
        let c = InputController()
        XCTAssertEqual(c.handle(KeyEvent(keyCode: 6, caps: false, hasOtherControl: true,
                                         kind: .flagsChanged, flags: 0)), .passthrough)
        XCTAssertEqual(c.handle(KeyEvent(keyCode: 1, caps: false, hasOtherControl: false,
                                         kind: .keyUp, flags: 0)), .passthrough)
    }
    func testDiphthongToneMovesCorrectly() {
        let c = InputController()
        _ = c.handle(keyDown("h")); _ = c.handle(keyDown("o")); _ = c.handle(keyDown("a"))
        let plan = c.handle(keyDown("f"))                            // hoa + f → hòa
        XCTAssertEqual(plan, .consume(backspaces: 2, chars: ["ò", "a"]))
    }
}
```
NOTE on `testDiphthongToneMovesCorrectly`: the exact `backspaces`/`chars` come from the engine's `EngineOutput` for `f` after `hoa`. If the faithful engine yields different values, set the expected to the ACTUAL engine output (print it once) — the engine is authoritative; this test pins the controller passes the engine output through unchanged, not a re-derivation.

- [ ] **Step 3: Run, verify pass** (adjust the diphthong expectation to the engine's real output if needed)

Run the Global-Constraints build/test command.
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Sources/Platform/InputController.swift Tests/PlatformTests/InputControllerTests.swift
git commit -m "feat(platform): add InputController (pure KeyEvent→SynthesisPlan core)"
```

---

### Task 4: KeySynthesizer (CGEvent backspace + unicode)

**Files:**
- Create: `Sources/Platform/KeySynthesizer.swift`

**Interfaces:**
- Produces: `final class KeySynthesizer { init(); var sourceStateID: Int64; func sendBackspaces(_ n:Int, proxy:CGEventTapProxy); func sendUnicode(_ chars:[Unicode.Scalar], proxy:CGEventTapProxy) }`.

VERIFICATION NOTE: this is CGEvent I/O — not unit-testable. Its verification is "compiles + covered by the Task 8 smoke script." Do NOT add assert-nothing tests.

- [ ] **Step 1: Create `Sources/Platform/KeySynthesizer.swift`**

Port the synthesis mechanics from `../mkey/Sources/Platform/MKEngineHook.mm` (backspace 537-550, unicode 576-666). Use a private source; post through the tap proxy so events reach the focused app; batch unicode at ≤16 chars/event.
```swift
import CoreGraphics

/// Synthesizes backspaces and Unicode insertions via a private event source.
/// The private source lets EventTap recognize and skip our own synthetic events.
final class KeySynthesizer {
    private let source: CGEventSource?
    let sourceStateID: Int64

    init() {
        let s = CGEventSource(stateID: .privateState)
        source = s
        sourceStateID = s.map { Int64(CGEventSourceGetSourceStateID($0).rawValue) } ?? -1
    }

    func sendBackspaces(_ n: Int, proxy: CGEventTapProxy) {
        guard n > 0 else { return }
        for _ in 0..<n {
            post(keyCode: 51, proxy: proxy)     // 51 = Backspace/Delete
        }
    }

    /// Insert Unicode scalars as text. keyCode 0 + SetUnicodeString = "type this string".
    func sendUnicode(_ chars: [Unicode.Scalar], proxy: CGEventTapProxy) {
        guard !chars.isEmpty else { return }
        var utf16: [UniChar] = []
        for c in chars { utf16.append(contentsOf: Array(String(c).utf16)) }
        var offset = 0
        while offset < utf16.count {
            let slice = Array(utf16[offset..<min(offset + 16, utf16.count)])
            postUnicode(slice, proxy: proxy)
            offset += slice.count
        }
    }

    private func post(keyCode: CGKeyCode, proxy: CGEventTapProxy) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = [.maskNonCoalesced]; up.flags = [.maskNonCoalesced]
        down.tapPostEvent(proxy); up.tapPostEvent(proxy)
    }

    private func postUnicode(_ utf16: [UniChar], proxy: CGEventTapProxy) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }
        var buf = utf16
        down.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: &buf)
        up.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: &buf)
        down.tapPostEvent(proxy); up.tapPostEvent(proxy)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build build 2>&1 | tail -8`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/Platform/KeySynthesizer.swift
git commit -m "feat(platform): add KeySynthesizer (backspace + unicode via private source)"
```

---

### Task 5: EventTap (tap creation + callback + recovery)

**Files:**
- Create: `Sources/Platform/EventTap.swift`

**Interfaces:**
- Consumes: `InputController`, `KeySynthesizer`, `KeyEvent`, `SynthesisPlan`.
- Produces: `final class EventTap { init(controller:InputController, synthesizer:KeySynthesizer); @discardableResult func start() -> Bool; func stop(); func reEnable() }`.

VERIFICATION NOTE: CGEvent I/O — not unit-testable. Verification is "compiles + Task 8 smoke script (typing works, ⌥Z, recovery)."

- [ ] **Step 1: Create `Sources/Platform/EventTap.swift`**

C callback bridging: `CGEvent.tapCreate` takes a `CGEventTapCallBack` (a `@convention(c)` function). Pass a top-level function and hand `self` through `userInfo` (refcon). Port tap flags from `../mkey/Sources/Platform/MKBridge.mm:82-112` and the callback/recovery/self-filter from `MKEngineHook.mm:759-778, 762-765`.
```swift
import CoreGraphics
import Foundation

final class EventTap {
    private let controller: InputController
    private let synthesizer: KeySynthesizer
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(controller: InputController, synthesizer: KeySynthesizer) {
        self.controller = controller
        self.synthesizer = synthesizer
    }

    /// Returns false if the tap could not be created (usually: Accessibility not granted).
    @discardableResult
    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else { return false }
        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        tap = nil; runLoopSource = nil
    }

    func reEnable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    /// Called by the C callback. Returns the (possibly nil) event to forward.
    func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Auto-recovery: macOS disabled the tap (slow callback / too many keys).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            reEnable()
            return Unmanaged.passUnretained(event)
        }
        // Skip our own synthesized events.
        if event.getIntegerValueField(.eventSourceStateID) == synthesizer.sourceStateID {
            return Unmanaged.passUnretained(event)
        }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let caps = flags.contains(.maskShift) || flags.contains(.maskAlphaShift)
        let hasOtherControl = flags.contains(.maskControl) || flags.contains(.maskCommand)
            || flags.contains(.maskAlternate) || flags.contains(.maskSecondaryFn)
        let kind: KeyEvent.Kind = type == .keyDown ? .keyDown
            : (type == .keyUp ? .keyUp : .flagsChanged)
        let ke = KeyEvent(keyCode: keyCode, caps: caps, hasOtherControl: hasOtherControl,
                          kind: kind, flags: flags.rawValue)

        switch controller.handle(ke) {
        case .passthrough:
            return Unmanaged.passUnretained(event)
        case .toggleLanguage:
            return nil                               // consume ⌥Z (state already flipped)
        case .consume(let backspaces, let chars):
            synthesizer.sendBackspaces(backspaces, proxy: proxy)
            synthesizer.sendUnicode(chars, proxy: proxy)
            return nil                               // swallow the original key
        }
    }
}

/// Top-level C callback: unwrap refcon → EventTap.
private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType,
                              event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
    return tap.handle(proxy: proxy, type: type, event: event)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build build 2>&1 | tail -8`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/Platform/EventTap.swift
git commit -m "feat(platform): add EventTap (CGEventTap + callback + auto-recovery)"
```

---

### Task 6: PermissionMonitor

**Files:**
- Create: `Sources/Platform/PermissionMonitor.swift`

**Interfaces:**
- Produces: `enum PermissionMonitor { static var isTrusted:Bool; static func prompt(); static func waitUntilTrusted(pollInterval:TimeInterval, onGranted:@escaping ()->Void) }`.

VERIFICATION NOTE: AX I/O — not unit-testable. Verification is "compiles + Task 8 smoke script (permission prompt appears, tap starts after grant)."

- [ ] **Step 1: Create `Sources/Platform/PermissionMonitor.swift`**

```swift
import ApplicationServices
import Foundation

/// Accessibility trust: dkey needs it to run a session event tap.
enum PermissionMonitor {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Show the system prompt directing the user to Privacy ▸ Accessibility.
    static func prompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Poll until trust is granted, then call onGranted once (on the main queue).
    static func waitUntilTrusted(pollInterval: TimeInterval = 1.0, onGranted: @escaping () -> Void) {
        if isTrusted { onGranted(); return }
        Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { timer in
            if isTrusted { timer.invalidate(); onGranted() }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the Global-Constraints `build` command (not test).
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/Platform/PermissionMonitor.swift
git commit -m "feat(platform): add PermissionMonitor (AX trust check + prompt + poll)"
```

---

### Task 7: App lifecycle wiring (permission → tap, sleep/wake, menu sync)

**Files:**
- Modify: `Sources/App/AppState.swift`
- Modify: `Sources/App/DkeyApp.swift`

**Interfaces:**
- Consumes: `InputController`, `KeySynthesizer`, `EventTap`, `PermissionMonitor`.
- Produces: `AppState.controller: InputController`; `AppState.hasAccessibility: Bool` (published); lifecycle in `DkeyAppDelegate`.

VERIFICATION NOTE: glue — verified by build + Task 8 smoke script (icon reflects state, menu toggle + ⌥Z both flip, permission gating, wake re-arm).

- [ ] **Step 1: Add the controller + permission state to `AppState`**

In `Sources/App/AppState.swift`, add to the `AppState` class (keep existing members):
```swift
    /// The engine + decision core driving the event tap (Phase 2).
    let controller = InputController()
    @Published var hasAccessibility: Bool = false
```
And make the menu toggle drive the controller. Change `isVietnamese`'s declaration to keep the published property but sync the controller on set:
```swift
    @Published var isVietnamese: Bool = true {
        didSet { controller.setVietnamese(isVietnamese) }
    }
```
Wire the reverse direction (hotkey → UI) in Step 2 via `controller.onLanguageChanged`.

- [ ] **Step 2: Lifecycle in `DkeyApp.swift`**

Extend `DkeyAppDelegate` (replace the Phase-0 `applicationDidFinishLaunching` body) to own the platform layer and start it once Accessibility is granted:
```swift
final class DkeyAppDelegate: NSObject, NSApplicationDelegate {
    private let synthesizer = KeySynthesizer()
    private var eventTap: EventTap?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState.shared
        // Hotkey → UI: reflect language flips back into AppState (icon/menu).
        state.controller.onLanguageChanged = { [weak state] vi in
            DispatchQueue.main.async { state?.reflectLanguageFromEngine(vi) }
        }
        let tap = EventTap(controller: state.controller, synthesizer: synthesizer)
        eventTap = tap

        PermissionMonitor.prompt()
        PermissionMonitor.waitUntilTrusted { [weak state] in
            state?.hasAccessibility = true
            _ = tap.start()
        }

        // Re-arm the tap after the machine wakes (macOS disables taps on sleep).
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.eventTap?.reEnable()
        }
    }
}
```
Add to `AppState` a setter that updates the published flag WITHOUT re-triggering the controller (avoid a feedback loop with `isVietnamese.didSet`):
```swift
    /// Called from the engine/hotkey side; updates UI state without re-notifying the engine.
    func reflectLanguageFromEngine(_ vi: Bool) {
        if isVietnamese != vi { _isReflecting = true; isVietnamese = vi; _isReflecting = false }
    }
    private var _isReflecting = false
```
And guard the `didSet` so a hotkey-driven reflect doesn't call `setVietnamese` again:
```swift
    @Published var isVietnamese: Bool = true {
        didSet { if !_isReflecting { controller.setVietnamese(isVietnamese) } }
    }
```

- [ ] **Step 3: Build + run the app to smoke it once**

Run:
```bash
xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build build 2>&1 | tail -6
open build/Build/Products/Debug/dkey.app
```
Expected: `** BUILD SUCCEEDED **`; the app launches, prompts for Accessibility (first run), and shows the "V" menu-bar icon. (Full behavior is exercised in Task 8.)

- [ ] **Step 4: Run the unit tests to confirm no regressions**

Run the Global-Constraints build/test command.
Expected: `** TEST SUCCEEDED **` (Engine + Parity + Platform unit tests all green).

- [ ] **Step 5: Commit**

```bash
git add Sources/App/AppState.swift Sources/App/DkeyApp.swift
git commit -m "feat(app): wire event tap lifecycle — permission, tap start, sleep/wake, menu sync"
```

---

### Task 8: Manual smoke checklist + final verification

**Files:**
- Create: `scripts/verify-phase2.md`

- [ ] **Step 1: Create `scripts/verify-phase2.md`**

```markdown
# Phase 2 — Manual Smoke Verification

Build & launch:
    xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build build
    open build/Build/Products/Debug/dkey.app

Grant Accessibility when prompted (System Settings ▸ Privacy & Security ▸ Accessibility ▸ enable dkey), then re-launch if needed.

Check each item:
- [ ] Menu-bar shows the "V" icon.
- [ ] In TextEdit, type `tieesng vieejt` → renders `tiếng việt`.
- [ ] Type `dduongwf` → `đường` (đ + horn + huyền).
- [ ] Type `hoaf` → `hòa`; `quoocs` → `quốc`.
- [ ] Press ⌥Z → icon flips to "E"; typing `tieesng` now stays `tieesng` (raw).
- [ ] Press ⌥Z again → "V"; the menu "Tiếng Việt" toggle also flips the icon.
- [ ] ⌘C / ⌘A / arrow keys behave normally (not transformed or eaten).
- [ ] Sleep the machine (`pmset sleepnow` or close lid) → wake → typing still produces Vietnamese (tap re-armed).
- [ ] Hold ~8 keys at once to trip the tap timeout, release → typing still works (auto-recovery).

If any item fails, note it; the failing layer is EventTap (recovery/self-filter), KeySynthesizer (wrong chars/backspaces), or the InputController mapping.
```

- [ ] **Step 2: Full build + test one more time**

Run the Global-Constraints build/test command.
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Walk the smoke checklist**

Follow `scripts/verify-phase2.md` end-to-end. All items should pass. If a curated example's expected output is uncertain, cross-check with the Phase-1 oracle (`printf 'INPUT\n' | scripts/openkey-oracle/oracle`).

- [ ] **Step 4: Commit**

```bash
git add scripts/verify-phase2.md
git commit -m "test(platform): add Phase 2 manual smoke verification checklist"
```

---

## Self-Review

**Spec coverage (vs `2026-07-03-dkey-phase2-platform-design.md`):**
- CGEventTap (session, head-insert, main run loop) → Task 5. ✅
- Key synthesis (backspace + unicode batch 16, private source) → Task 4. ✅
- Engine wiring + action→plan mapping → Task 3. ✅
- ⌥Z hotkey → toggle language + icon → Tasks 2, 3, 7. ✅
- Accessibility permission flow (prompt + poll) → Task 6, 7. ✅
- Event-tap auto-recovery → Task 5 (`handle` disabled-by-timeout branch). ✅
- Sleep/wake re-arm → Task 7 (`NSWorkspace.didWakeNotification`). ✅
- Self-event filter → Tasks 4 (sourceStateID) + 5 (compare). ✅
- Other-control passthrough → Task 3. ✅
- Testable core unit tests + manual smoke → Tasks 1-3 (TDD) + Task 8. ✅
- Deferred (slow-path, login-item, smart-switch, persistence) → none implemented. ✅

**Placeholder scan:** Adapter tasks (4,5,6,7) use build + smoke verification instead of unit tests — this is the honest verification for CGEvent/AX I/O and is stated explicitly (no assert-nothing tests). Task 3's diphthong test carries a note to pin the engine's actual output. No "TODO"/vague steps; all code blocks are complete. ✅

**Type consistency:** `KeyEvent`/`SynthesisPlan` (Task 1) used unchanged in Tasks 3, 5. `InputController.handle/setVietnamese/onLanguageChanged/isVietnamese/switchKeyStatus` consistent across Tasks 3, 7. `KeySynthesizer.sendBackspaces/sendUnicode/sourceStateID` consistent across Tasks 4, 5. `EventTap.start/stop/reEnable/handle` consistent across Tasks 5, 7. `HotkeyMatcher.matches(status:keyCode:flags:)` consistent across Tasks 2, 3. `AppState.controller/hasAccessibility/reflectLanguageFromEngine` consistent in Task 7. ✅

**Risks flagged in-plan:** C-callback refcon bridging (Task 5), engine's exact diphthong output for the controller test (Task 3), unicode post ordering (Task 4 batches; Task 5 sends backspaces-then-unicode) — each has concrete code or a note.
