# dkey Phase 2 — Platform Layer (Event Tap + Key Synthesis) Design Spec

**Ngày:** 2026-07-03
**Trạng thái:** Đã brainstorm & duyệt design — sẵn sàng viết implementation plan.
**Phase trước:** Phase 0 (scaffold) + Phase 1 (Telex engine, parity xanh) đã merge vào `main`.

---

## 1. Mục tiêu

Nối **engine Telex thuần Swift (Phase 1)** vào bàn phím thật của macOS: chặn keystroke bằng `CGEventTap`, đưa vào engine, rồi tổng hợp lại (xóa lùi + chèn ký tự Unicode). Sau Phase 2, dkey **gõ tiếng Việt được thật** trong mọi app tiêu chuẩn, với hotkey ⌥Z bật/tắt, xin quyền Accessibility, tự phục hồi event-tap, và re-arm khi máy thức dậy.

### Phạm vi — TRONG Phase 2
- `CGEventTap` (session, head-insert, `kCGEventTapOptionDefault`) trên main run loop, mask keyDown + keyUp + flagsChanged.
- Key synthesis: N backspace (keycode 51) + chèn chuỗi Unicode (`CGEventKeyboardSetUnicodeString`, batch ≤16) qua **private `CGEventSource`**; self-event filter bằng `kCGEventSourceStateID`.
- Wire engine Phase 1: VI mode ON + không giữ ⌘/⌃ → transform; áp `EngineOutput.action` contract (consume vs passthrough).
- Hotkey **⌥Z** (đọc từ `AppState.switchKeyStatus`) → toggle `AppState.isVietnamese`, `engine.newSession()`, đổi icon menu bar V/E.
- Accessibility permission flow: `AXIsProcessTrustedWithOptions(prompt)` + poll đến khi granted → start tap; menu phản ánh trạng thái.
- Event-tap **auto-recovery**: `kCGEventTapDisabledByTimeout`/`ByUserInput` → `CGEventTapEnable(true)`.
- **Sleep/wake** re-arm: `NSWorkspace.didWake` → re-enable tap (+ re-check quyền).
- Passthrough khi giữ modifier control (⌘C… không bị biến đổi).

### Phạm vi — HOÃN (phase sau)
AX slow-path Spotlight/Raycast + per-app/browser workaround (Phase 6); smart-switch auto VI/EN theo app (Phase 4); login-item SMAppService (Phase 5); persistence settings/nhớ VI-EN qua lần chạy (Phase 5); UI rebind hotkey (Phase 5); VNI/codepages/macro (đã hoãn từ P1).

### Success criteria
1. Unit test (`Tests/PlatformTests/`) cho `InputController` + `HotkeyMatcher` xanh: hotkey toggle, English passthrough, other-control passthrough, VI transform (`"a"`→passthrough, `"s"`→consume(1,"á")), wordBreak passthrough, caps.
2. Build `xcodebuild` sạch; app chạy dạng menu-bar (LSUIElement).
3. Smoke script `scripts/verify-phase2.md` pass bằng tay: gõ `tieesng vieejt`→`tiếng việt` trong TextEdit; ⌥Z đổi E + icon; ⌘C không bị biến đổi; wake rồi gõ vẫn chạy; giữ nhiều phím (timeout) rồi gõ vẫn chạy.

---

## 2. Bối cảnh & quyết định kiến trúc

- Engine Phase 1 (`Sources/Engine/`) cung cấp API thuần: `InputEngine.handle(key:caps:) -> EngineOutput`, `backspace()`, `newSession()`, `useModernOrthography`. `EngineOutput{backspaceCount, newChars:[Unicode.Scalar], action}` với `action ∈ {passthrough, process, wordBreak, restore}` (contract đã document ở `EngineOutput.swift`).
- Tham chiếu mkey `Sources/Platform/MKEngineHook.mm` (960 dòng, ObjC++) + `MKBridge.mm`. dkey **port sang Swift thuần** (bỏ ObjC++ bridge), giữ nguyên cơ chế CoreGraphics.
- **Quyết định: Hướng B — clean Swift wrapper, cơ chế proven.** Tách nhỏ: adapter CGEvent mỏng (khó test) + **lõi `InputController` thuần (testable)**. Mô hình chặn duy nhất khả thi là **consume-and-resynthesize** (một keyDown không thể "sửa tại chỗ" thành N delete + text). `NSEvent` global monitor bị loại (listen-only, không consume được).

### Ánh xạ `action` → hành vi tap (mấu chốt)
| `EngineOutput.action` | Tap |
|---|---|
| `.passthrough` | return event (OS tự gõ ký tự literal) — KHÔNG synthesize |
| `.wordBreak` | return event (OS gõ space/dấu câu); engine đã reset session |
| `.process` / `.restore` | return NULL (consume) + synthesize `backspaceCount` backspace rồi `newChars` |

**Bất biến đồng bộ:** màn hình luôn khớp buffer engine — phím thường được OS gõ đúng ký tự engine ghi (passthrough), phím biến đổi thì consume + tái tạo. Rủi ro: dead-key/layout không chuẩn có thể lệch (ngoài scope P2, ghi chú lại).

---

## 3. Kiến trúc module — `Sources/Platform/` (pure Swift, không ObjC++)

| File | Trách nhiệm | Test |
|---|---|---|
| `KeyEvent.swift` | Struct thuần mô tả 1 sự kiện: `{keyCode:UInt16, caps:Bool, hasOtherControl:Bool, kind: .keyDown/.keyUp/.flagsChanged, flags:UInt64}`. Không phụ thuộc CGEvent. | ✅ |
| `SynthesisPlan.swift` | Enum kết quả quyết định: `.passthrough`, `.toggleLanguage`, `.consume(backspaces:Int, chars:[Unicode.Scalar])`. | ✅ |
| `InputController.swift` | **Lõi thuần, testable.** Sở hữu `TelexEngine`; đọc/ghi `isVietnamese`/`switchKeyStatus` (qua `AppState`). `handle(KeyEvent) -> SynthesisPlan`: match hotkey → English passthrough → other-control passthrough+newSession → engine.handle → map action→plan. `flagsChanged`/`keyUp` → passthrough (cập nhật flags theo dõi). | ✅ unit |
| `HotkeyMatcher.swift` | So khớp bitfield `switchKeyStatus` (⌥Z = `0x7A000206`) với keyCode + modifier flags. | ✅ unit |
| `KeySynthesizer.swift` | CGEvent I/O: private `CGEventSource(kCGEventSourceStatePrivate)`; `sendBackspaces(_ n:)` (keycode 51 down/up); `sendUnicode(_ chars:)` (keycode 0 + `CGEventKeyboardSetUnicodeString`, batch 16); post qua `CGEventTapPostEvent`/`CGEventPost`. | ⚠️ thin, manual |
| `EventTap.swift` | Tạo/enable `CGEventTapCreate` + `CFRunLoopAddSource`; C-callback (`@convention(c)` top-level fn + `refcon`→`Unmanaged<EventTap>`); self-event filter (`kCGEventSourceStateID`); auto-recovery; build `KeyEvent`, gọi `InputController` → thực thi `SynthesisPlan` qua `KeySynthesizer`. `reEnable()`. | ⚠️ thin, manual |
| `PermissionMonitor.swift` | `AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`; timer poll ~1s; callback báo granted cho lifecycle/UI. | ⚠️ thin |

**Glue (App):** mở rộng `DkeyAppDelegate` (hoặc `EngineHook.swift`): lifecycle xin-quyền→start-tap, `NSWorkspace` sleep/wake observers, nối `AppState` (icon/menu). `MenuContent` Toggle "Tiếng Việt" và ⌥Z cùng đổi `AppState.isVietnamese`.

**Ranh giới test:** mọi *logic quyết định* nằm trong `InputController` (+`HotkeyMatcher`) — thuần, unit test kỹ. `EventTap`/`KeySynthesizer`/`PermissionMonitor` là adapter CoreGraphics mỏng → verify bằng smoke script tay.

---

## 4. Luồng dữ liệu

```
Physical key
  ↓  CGEventTap (session, head-insert, main run loop)
EventTap C-callback(proxy, type, event, refcon)
  ├─ type == kCGEventTapDisabledByTimeout|ByUserInput → CGEventTapEnable(tap,true); return event
  ├─ CGEventGetIntegerValueField(event,kCGEventSourceStateID)==ourSourceStateID → return event  (self-event)
  ├─ keyCode = CGEventGetIntegerValueField(event,kCGKeyboardEventKeycode)
  │  flags   = CGEventGetFlags(event); caps = shift|alphaShift; hasOtherControl = control|command
  │  KeyEvent ← (keyCode, caps, hasOtherControl, kind, flags)
  ├─ plan = InputController.handle(KeyEvent)
  └─ switch plan:
       .passthrough          → return event
       .toggleLanguage       → AppState.isVietnamese.toggle(); engine.newSession(); (beep?); return NULL
       .consume(bks, chars)  → KeySynthesizer.sendBackspaces(bks); KeySynthesizer.sendUnicode(chars); return NULL
```

Lifecycle: `applicationDidFinishLaunching` → `PermissionMonitor`: nếu trusted `EventTap.start()`; nếu chưa, prompt + poll → khi granted `EventTap.start()`. `NSWorkspace.didWake` → `EventTap.reEnable()`.

---

## 5. Error handling & edge cases
- **Chưa cấp quyền:** `CGEventTapCreate` trả `nil` → không crash; menu báo "cần cấp quyền trong System Settings ▸ Privacy ▸ Accessibility"; poll cho tới khi được rồi start.
- **Tap bị disable (timeout/user-input):** re-enable ngay trong callback.
- **Sleep/wake:** re-enable khi thức dậy (tap thường bị macOS tắt khi ngủ).
- **Self-event loop:** mọi event synthesize mang private source → filter ở đầu callback, không xử lý lại.
- **Modifier shortcut (⌘/⌃):** passthrough + `newSession()` (ngắt từ đang gõ) để không phá ⌘C/⌃A…
- **⌥Z bị OS gõ thành ký tự đặc biệt:** consume (return NULL) nên không chèn ký tự option-Z.
- **Buffer > MAX_BUFF:** engine đã tự quản (Phase 1); tap chỉ áp output.

---

## 6. Testing

### Unit (`Tests/PlatformTests/`, thuần, không CGEvent)
`InputController` dùng `TelexEngine` thật:
- Hotkey ⌥Z (keyDown Z + option) → `.toggleLanguage`, và lần 2 toggle lại.
- English mode (`isVietnamese=false`) → mọi phím `.passthrough`.
- Other-control (`hasOtherControl=true`) → `.passthrough` (và session reset).
- VI mode: `"a"` → `.passthrough`; kế tiếp `"s"` → `.consume(1, ["á"])`; `"f"` sau "hoa" → `.consume(...)` đúng "hòa".
- wordBreak (space) → `.passthrough`.
- caps: shift+key → engine nhận caps=true.
`HotkeyMatcher`: khớp/không khớp theo tổ hợp modifier + keyCode.

### Manual smoke (`scripts/verify-phase2.md` — checklist)
1. Cấp quyền Accessibility khi được hỏi; icon "V" xuất hiện.
2. Trong TextEdit gõ `tieesng vieejt` → "tiếng việt".
3. ⌥Z → icon đổi "E", gõ `tieesng` ra "tieesng" (raw).
4. ⌥Z lại → "V"; ⌘C không biến đổi; ⌘A, mũi tên hoạt động bình thường.
5. Đóng nắp/ngủ (hoặc `pmset sleepnow`) rồi thức dậy → gõ vẫn ra tiếng Việt.
6. Giữ nhiều phím cùng lúc (kích timeout) → sau đó gõ vẫn hoạt động (auto-recovery).

### Build/verify
`xcodegen generate && rm -rf build && xcodebuild ... build test` (test target chạy PlatformTests + Engine/Parity cũ). Chạy thật: `open build/Build/Products/Debug/dkey.app`.

---

## 7. Rủi ro & open questions
- **C-callback trong Swift:** `CGEventTapCreate` cần `CGEventTapCallBack` (C function pointer). Dùng top-level `@convention(c)` fn + `refcon`=`Unmanaged.passUnretained(eventTap).toOpaque()`; trong callback `Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()`. Xác minh khi implement.
- **Đồng bộ màn hình vs buffer** với dead-key/bàn phím non-US: ngoài scope P2.
- **Quyền trong khi test:** unit test KHÔNG cần quyền (InputController thuần). Smoke script cần cấp quyền tay.
- **`CGEventTapPostEvent` vs `CGEventPost`:** post trong callback dùng proxy (`CGEventTapPostEvent(proxy, …)`) để chèn đúng luồng; xác minh thứ tự backspace→unicode khi implement.

---

## 8. Self-review
- **Phạm vi:** đủ nhỏ cho 1 plan (tap + synth + permission + recovery + sleep/wake + hotkey), hoãn rõ ràng slow-path/login-item/smart-switch. ✅
- **Nhất quán:** `SynthesisPlan`/`KeyEvent`/`InputController` dùng nhất quán mục 3–4–6; ánh xạ `action`→tap (mục 2) khớp logic InputController (mục 4). ✅
- **Không placeholder:** mọi mục có nội dung cụ thể; 2 open question (C-callback, post ordering) là việc xác minh khi implement, không phải lỗ hổng thiết kế. ✅
- **Không mơ hồ:** ranh giới testable (InputController) vs thin-adapter rõ; consume-vs-passthrough theo `action` rõ; single source of truth = `AppState.isVietnamese`. ✅
