# dkey — Design spec: port MKey/OpenKey sang Swift native

**Ngày:** 2026-06-17
**Trạng thái:** Đã chốt design, sẵn sàng viết implementation plan.
**Liên quan:** `docs/2026-06-17-port-strategy.md` (brainstorm chiến lược gốc).

## 0. Quyết định đã chốt (resolve open questions của port-strategy)

| Mục | Quyết định | Ghi chú |
|---|---|---|
| License/port | **B — Port trực tiếp OpenKey/MKey → Swift, GPL v3** | Được phép đọc source `../mkey`. License `dkey` đổi MIT → GPL v3. |
| Engine port style | **Dịch + refactor sạch thành module Swift** | Đẹp hơn nhưng rủi ro parity → ParityTests là trụ cột. |
| MVP scope | **Full parity với MKey** | Telex + VNI + tất cả bảng mã + macro + smart switch + convert tool + toàn bộ platform/UI. |
| Distribution | Ad-hoc DMG, tự dùng | Chưa cần Apple Developer account. Notarize để phase sau. |
| Target macOS | **14+** | Giống MKey. SMAppService + MenuBarExtra. |
| Tên hiển thị | `dkey` | |
| Phím chuyển ngôn ngữ mặc định | **⌥Z** (Alt+Z, switch status `0x7A000206`) | Giống MKey. |
| Bundle ID | `com.datnm555.dkey` | |

## 1. Bối cảnh nguồn (MKey thực tế)

Đã khảo sát `../mkey` (XcodeGen, macOS 14+):

- **Engine C++** (`Sources/Engine/`, 3,258 LOC):
  - `Engine.cpp` (1,558) — state machine Telex/VNI **monolithic** chung buffer `TypingWord[32]`, lookahead/rollback, spell-check, restore. Entry: `vKeyHandleEvent`, `startNewSession`, `vKeyInit`, `vTempOffEngine`, `getCharacterCode`.
  - `Engine.h` (245) — 21 global `extern int` cấu hình (vLanguage, vInputType, vCodeTable, vCheckSpelling, ...).
  - `Vietnamese.cpp` (575) — bảng nguyên âm/phụ âm/tone, code tables (Unicode/TCVN3/VNI/Compound/CP1258), `_characterMap`.
  - `Macro.cpp` (293) — gõ tắt, serialize binary length-prefixed.
  - `ConvertTool.cpp` (180) — convert clipboard giữa 5 bảng mã + case transform.
  - `SmartSwitchKey.cpp` (73) — nhớ language+codeTable theo bundleId, serialize binary.
  - `DataType.h` (156) — enums, structs (`vKeyHookState`), bit masks tone/mark/caps.
- **Bridge ObjC++** (`Sources/Platform/`, 1,434 LOC): `MKGlobals.h`, `MKBridge.h/.mm` (facade + CGEventTap lifecycle), `MKEngineHook.mm` (960 — CGEventTap callback, key synthesis, AX workarounds, smart-switch hooks). **Sẽ bỏ hoàn toàn.**
- **UI SwiftUI** (`Sources/App/`, 1,454 LOC): `MkeyApp` (@main, MenuBarExtra+Window), `AppState` (singleton mirror 30+ settings), `StatusIcon`, `KeyRecorderField`, `HotkeyEditor`, Views: Typing/Macro/Convert/System/About.
- **Persistence**: NSUserDefaults cho settings; binary NSData blob cho macro + smart-switch.
- **Info.plist**: `LSUIElement: true`, region `vi`. **Entitlements rỗng**, **sandbox OFF** (cần CGEventTap). Accessibility permission qua prompt. Login item qua SMAppService.

## 2. Kiến trúc dkey (3 lớp, thuần Swift)

```
dkey/
├── project.yml                     # XcodeGen, macOS 14+, GPL v3
├── LICENSE                         # đổi MIT → GPL v3
├── scripts/
│   ├── make_icon.swift
│   └── make_dmg.sh                 # đóng gói DMG ad-hoc sau xcodebuild
├── Sources/
│   ├── Engine/                     # Pure Swift, KHÔNG phụ thuộc AppKit
│   ├── Platform/                   # macOS glue, vẫn Swift
│   ├── App/                        # SwiftUI
│   └── Support/                    # Info.plist, dkey.entitlements, Assets.xcassets
└── Tests/
    ├── EngineTests/
    └── ParityTests/
```

Khác MKey: 1 ngôn ngữ (Swift) thay 3; bỏ bridge ObjC++; engine dùng `EngineCore` instance + `EngineConfig` struct thay 21 global.

## 3. Engine layer (refactor sạch)

Pure Swift, không import AppKit. Protocol `InputEngine` để mock.

| File | Nguồn C++ | Trách nhiệm |
|---|---|---|
| `Models.swift` | DataType.h | enum `InputType` (telex/vni/simpleTelex1/simpleTelex2), `CodeTable` (unicode/tcvn3/vni/compound/cp1258), `KeyEvent` (keyCode, state, caps, otherControlKey), `HookResult` (backspaceCount, newChars, extCode). Bit masks tone/mark/caps. |
| `EngineConfig.swift` | Engine.h globals | struct gom 21 cờ cấu hình (language, inputType, codeTable, checkSpelling, modernOrthography, freeMark, quickTelex, restoreIfWrong, fixRecommendBrowser, upperCaseFirstChar, tempOffSpelling, allowZFWJ, quickStartConsonant, quickEndConsonant, useMacro, useMacroInEnglishMode, autoCapsMacro, useSmartSwitch, rememberCode, otherLanguage, tempOffEngine). |
| `VietnameseData.swift` | Vietnamese.cpp | bảng nguyên âm/phụ âm/tone, `_characterMap`, 5 code tables — dữ liệu thuần (static let). |
| `TelexProcessor.swift` | Engine.cpp (telex) | rule Telex tách riêng, vận hành trên `TypingWord` buffer. |
| `VNIProcessor.swift` | Engine.cpp (vni) | rule VNI tách riêng. |
| `ToneEngine.swift` | Engine.cpp | đặt/gỡ dấu thanh, modern vs old orthography, spell-check, restore-if-wrong-spelling. |
| `Codepage.swift` | ConvertTool.cpp + Vietnamese.cpp | Unicode ↔ TCVN3/VNI/Compound/CP1258 + convert tool (case transform, remove mark). |
| `MacroStore.swift` | Macro.cpp | gõ tắt: add/delete/find/getAll, serialize **JSON Codable**. |
| `SmartSwitchStore.swift` | SmartSwitchKey.cpp | nhớ (language, codeTable) theo bundleId, serialize **JSON Codable**. |
| `EngineCore.swift` | Engine.cpp facade | `handle(_ event: KeyEvent) -> HookResult`, `startNewSession()`, `tempOff(_:)`, điều phối Telex/VNI/Tone. Facade DUY NHẤT Platform gọi vào. |

Telex & VNI chia sẻ `TypingWord` buffer + state list (giữ thuật toán lookahead/rollback của OpenKey) nhưng tách rule. `EngineCore` conform `InputEngine` protocol.

## 4. Platform layer (Swift thuần, thay ObjC++)

| File | Nguồn | Trách nhiệm |
|---|---|---|
| `EventTap.swift` | MKEngineHook.mm | CGEventTap wrapper, C callback (`@_cdecl`/CFMachPort), re-enable sau system timeout, post synthesized events. |
| `KeySynth.swift` | MKEngineHook.mm | synthesize backspace + ký tự: pure Unicode, keycode+shift, 2-byte VNI/TCVN3, Unicode Compound mark. |
| `AccessibilityAX.swift` | MKEngineHook.mm | AX direct-edit text cho slow-path apps (tránh xáo trộn khi gõ nhanh). |
| `AppWorkarounds.swift` | MKEngineHook.mm | niceSpaceApp (Sublime: 0x200C), unicodeCompoundApp (Apple/Chrome/Edge tránh Compound), slowPathApp (Spotlight/Raycast/Alfred). |
| `PermissionMonitor.swift` | MkeyApp.swift | `AXIsProcessTrustedWithOptions` prompt, poll 1.5s. |
| `Persistence.swift` | MKBridge.mm | UserDefaults cho settings; JSON file cho macro + smart-switch. |
| `LoginItem.swift` | AppState.swift | SMAppService.mainApp register/unregister. |
| `WorkspaceMonitor.swift` | MkeyApp.swift | sleep/wake (re-enable tap), space change (new session), active app change (smart switch). |

## 5. App layer (SwiftUI, bám sát MKey)

- `DkeyApp.swift` — @main, Scene: MenuBarExtra + Window, AppDelegate (workspace notifications, accessibility check, start engine).
- `AppState.swift` — @Observable singleton, mirror toàn bộ config, `reloadFromEngine()` khi engine đổi state (hotkey/smart-switch), `resetToDefaults()`, `hotkeyDescription()`.
- `StatusIcon.swift` — render "V"/"E" trong khung bo góc (CoreGraphics), template image hoặc màu.
- `KeyRecorderField.swift` — ghi hotkey (NSEvent local monitor), keyCode + displayChar.
- `HotkeyEditor.swift` — row: 4 modifier toggle (⌃⌥⌘⇧) + KeyRecorderField + live preview.
- Views: `SettingsRootView` (sidebar TabView 5 page), `TypingPage`, `MacroPage`, `ConvertPage`, `SystemPage`, `AboutPage` (giữ attribution OpenKey © Tuyen Mai, GPL v3).

## 6. Persistence

- Settings → `UserDefaults` (giữ key tương thích MKey khi hợp lý).
- Macro + smart-switch → **JSON Codable** file trong Application Support (thay binary blob OpenKey — dễ debug/test/diff).
- Login item → SMAppService (không lưu trong UserDefaults).

## 7. Testing (trụ cột vì chọn refactor sạch)

- **EngineTests**: unit test từng processor — Telex, VNI, Tone, Codepage (5 bảng mã round-trip), Macro (CRUD + serialize), SmartSwitch.
- **ParityTests**:
  1. Build 1 lần engine C++ gốc thành CLI nhỏ (`openkey-oracle`) đọc chuỗi keystroke → in output.
  2. Sinh corpus `(input keystrokes → expected output)` cho hàng nghìn từ/câu tiếng Việt (đủ tone, các bảng mã, edge case: zfwj, quick telex, restore wrong spelling).
  3. Test dkey assert output **y hệt** oracle.
  4. Corpus commit vào repo (file fixture) để CI chạy không cần build C++ lại.

## 8. Info.plist / entitlements

- `LSUIElement: true` (menu-bar only, override bởi showIconOnDock).
- `CFBundleDevelopmentRegion: vi`, `CFBundleIdentifier: com.datnm555.dkey`.
- `NSHumanReadableCopyright`: attribution OpenKey (Tuyen Mai, GPL v3).
- Entitlements rỗng, **sandbox OFF** (cần CGEventTap). Có thể bật hardened runtime khi notarize (phase sau).
- Accessibility permission qua prompt runtime.

## 9. Roadmap (~3.5–4.5 tuần solo)

| Phase | Nội dung | TG |
|---|---|---|
| 0 | Scaffold XcodeGen, đổi LICENSE→GPL v3, Info.plist/entitlements, MenuBar + Settings skeleton chạy được | 3 ngày |
| 1 | Engine: Telex + ToneEngine + Unicode output + ParityTests harness (oracle CLI + corpus) | 1 tuần |
| 2 | Platform: EventTap + KeySynth + PermissionMonitor + sleep/wake | 1 tuần |
| 3 | Engine: VNI + bảng mã TCVN3/VNI/Compound/CP1258 + ConvertTool | 4 ngày |
| 4 | Engine: Macro + SmartSwitch (JSON) | 3 ngày |
| 5 | App: Settings UI đầy đủ (5 page) + persistence + KeyRecorder | 5 ngày |
| 6 | AX slow-path + per-app workarounds + polish | 4 ngày |
| 7 | Script DMG ad-hoc + README | 2 ngày |

Notarize/Developer ID là phase riêng sau khi có account.

## 10. Rủi ro & giảm thiểu

| Rủi ro | Giảm thiểu |
|---|---|
| Refactor lệch hành vi OpenKey | ParityTests với oracle CLI (mục 7) — lưới an toàn chính. |
| Key synthesis sai cho 2-byte/Compound | Test KeySynth riêng + thử thực tế trên app target. |
| Slow-path apps (Spotlight) xáo chữ | Port nguyên logic AX direct-edit MKey, test thủ công. |
| Event tap bị disable sau timeout | Port logic re-enable của MKEngineHook. |
| GPL v3 compliance | Giữ attribution + LICENSE GPL v3 trong repo và AboutPage. |
