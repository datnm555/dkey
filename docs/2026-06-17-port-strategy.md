# dkey — Chiến lược port từ MKey/OpenKey sang Swift native

**Ngày:** 2026-06-17
**Trạng thái:** Đang brainstorm — chưa bắt đầu code.

## 1. Bối cảnh

`dkey` sẽ là bộ gõ tiếng Việt cho macOS, lấy cảm hứng từ:

- **OpenKey** (Tuyen Mai, GPL v3) — engine C++ ~3,500 LOC, battle-tested.
- **MKey** (`maclifevn/mkey`, GPL v3) — UI SwiftUI hiện đại bọc lên engine OpenKey, có MenuBarExtra, SMAppService, event-tap auto-recovery.

Repo tham chiếu đã clone về `../mkey/` (cùng working directory).

## 2. Quyết định đã chốt

| Mục | Quyết định | Lý do |
|---|---|---|
| Ngôn ngữ engine | **Swift native** | Loại bỏ lớp ObjC++ bridge, cùng module với UI, ARC deterministic, XCTest sẵn. |
| Platform | **macOS 14+** | Theo MKey, dùng SMAppService + MenuBarExtra SwiftUI. |
| Input method API | **Accessibility (CGEventTap)** | Giữ giống MKey để Spotlight hoạt động tốt. POC IMK để sau. |

## 3. Quyết định CHƯA chốt — cần resolve trước khi code

### 3.1 License & cách port engine ⚠ Blocker

`dkey` hiện là **MIT**. Engine OpenKey + MKey là **GPL v3**. Cách port quyết định license cuối cùng:

| Option | Cách làm | License kết quả | Thời gian (solo) |
|---|---|---|---|
| **A. Clean-room + MIT** ✅ recommend | Không nhìn source OpenKey/MKey. Chỉ đọc spec Telex/VNI/bảng mã (công khai). Tự implement. | MIT giữ nguyên | ~5–7 tuần |
| **B. Port trực tiếp + GPL v3** | Đọc `Engine.cpp/Vietnamese.cpp` rồi dịch sang Swift. | Bắt buộc GPL v3 (viral) | ~3–4 tuần |
| **C. Hybrid** | Telex/VNI clean-room, bảng mã + macro port | Vẫn GPL v3 | ~4–5 tuần |

**Lý do recommend A:**

1. GPL v3 viral — bất kỳ ai dùng `dkey` sau này phải GPL hoá app của họ.
2. Logic bộ gõ tiếng Việt KHÔNG bí mật — Telex/VNI/Unicode/TCVN3/VNI/VIQR/VPS đều là chuẩn công khai, có trên Wikipedia.
3. Chênh lệch chỉ ~2–3 tuần — rất rẻ để giữ MIT (đưa lên Mac App Store, bán Pro, dùng làm SDK).
4. `dkey` đã chủ động chọn MIT từ đầu → giữ nhất quán.

**Khi nào chọn B:** ship trong 2–3 tuần, OK với GPL v3, không có ý định monetize/distribute kín.

**Khi nào chọn C:** không nên — tệ nhất của cả hai (dính GPL nhưng không nhanh bằng B).

**👉 Cần user xác nhận: A / B / C.**

### 3.2 Scope MVP

Cần chốt feature nào vào MVP, feature nào để sau:

| Feature | MVP? |
|---|---|
| Telex | bắt buộc |
| VNI | ? |
| Bảng mã Unicode | bắt buộc |
| Bảng mã TCVN3, VNI, VIQR, VPS | ? |
| Gõ tắt (macro) | ? |
| Smart switch (auto Vi/En) | ? |
| Chuyển mã (convert tool) | ? |
| Per-app override behavior | ? |
| Phím chuyển ngôn ngữ tuỳ biến | bắt buộc |
| MenuBarExtra với icon VI/EN | bắt buộc |
| Settings window SwiftUI | bắt buộc |
| Login item (SMAppService) | bắt buộc |
| Accessibility permission flow | bắt buộc |
| Event tap auto-recovery | bắt buộc |
| Sleep/wake handling | bắt buộc |
| Per-app workaround (Spotlight/Raycast/Sublime) | nên có |

**👉 Cần user chốt các ô `?`.**

### 3.3 Distribution

| Mức | Yêu cầu | Phù hợp giai đoạn |
|---|---|---|
| Ad-hoc DMG (tự dùng) | `xcodebuild` + `hdiutil` | MVP, dev test |
| Developer ID + notarize DMG | Apple Dev account ($99/năm), GitHub Actions workflow | Public release |
| Mac App Store | Sandbox + entitlements review | Sau — bộ gõ thường bị App Store reject vì cần CGEventTap |

**👉 Cần user xác nhận có Apple Developer account không, có muốn public release không.**

## 4. Kiến trúc đề xuất (sau khi loại ObjC++ bridge)

```
dkey/
├── project.yml                 # XcodeGen
├── scripts/
│   ├── make_icon.swift
│   └── make_dmg.sh             # đóng gói DMG sau xcodebuild
├── Sources/
│   ├── Engine/                 # Pure Swift, không phụ thuộc AppKit
│   │   ├── Telex.swift         # state machine Telex
│   │   ├── VNI.swift           # state machine VNI
│   │   ├── Vietnamese.swift    # tone mark rules, vowel detection
│   │   ├── Codepage.swift      # Unicode <-> TCVN3/VNI/VIQR/VPS
│   │   ├── Macro.swift         # gõ tắt
│   │   ├── SmartSwitch.swift   # auto Vi/En
│   │   ├── EngineCore.swift    # facade: input(key) -> output actions
│   │   └── Models.swift        # InputType, CodeTable, KeyEvent, ...
│   ├── Platform/               # macOS-specific glue, vẫn Swift
│   │   ├── EventTap.swift      # CGEventTap wrapper với @_cdecl callback
│   │   ├── KeySynth.swift      # synthesize CGEvent backspace/replacement
│   │   ├── AccessibilityAX.swift  # AX direct edit cho slow-path apps
│   │   ├── PermissionMonitor.swift # poll AXIsProcessTrusted
│   │   └── Persistence.swift   # UserDefaults + JSON cho macro
│   ├── App/                    # SwiftUI
│   │   ├── DkeyApp.swift       # @main, MenuBarExtra, Window
│   │   ├── AppState.swift      # @Observable singleton
│   │   ├── StatusIcon.swift
│   │   ├── KeyRecorderField.swift
│   │   └── Views/
│   │       ├── SettingsRootView.swift
│   │       ├── GeneralSettings.swift
│   │       ├── InputMethodSettings.swift
│   │       ├── MacroSettings.swift
│   │       ├── PerAppSettings.swift
│   │       └── AboutView.swift
│   └── Support/
│       ├── Info.plist
│       ├── dkey.entitlements   # tắt sandbox, có thể bật hardened runtime
│       └── Assets.xcassets
└── Tests/
    ├── EngineTests/            # unit test cho Telex/VNI/Codepage/Macro
    ├── PlatformTests/          # mock event tap, test recovery flow
    └── ParityTests/            # so sánh output dkey vs OpenKey trên corpus
```

### Điểm khác MKey

| MKey | dkey |
|---|---|
| 3 ngôn ngữ (C++/ObjC++/Swift) | 1 ngôn ngữ (Swift) |
| Bridge ObjC++ ~1000 LOC | Bỏ hoàn toàn |
| Engine globals (extern int) | `EngineCore` instance, không global |
| Class methods `MKBridge` | Protocol `InputEngine` (mock-able) |
| Không test | XCTest từ ngày đầu |
| UserDefaults blob nhị phân | JSON Codable + UserDefaults cho settings |
| Per-app whitelist hard-code | JSON config (`per-app.json`) |
| Không CI | GitHub Actions build + (sau) notarize |

## 5. Roadmap thô (Clean-room + MIT, ~6 tuần solo)

| Phase | Nội dung | Thời gian |
|---|---|---|
| 0 | Project scaffold (XcodeGen, structure, CI build), Settings skeleton, MenuBarExtra | 3 ngày |
| 1 | Engine: Telex + Vietnamese tone marks + Unicode output. Test parity corpus. | 1 tuần |
| 2 | Platform: CGEventTap + KeySynth + Accessibility permission + sleep/wake | 1 tuần |
| 3 | Engine: VNI + bảng mã TCVN3/VNI/VIQR/VPS | 4 ngày |
| 4 | Engine: Macro + SmartSwitch | 4 ngày |
| 5 | App: Settings UI hoàn chỉnh, KeyRecorder, persistence JSON | 1 tuần |
| 6 | AX direct-edit cho Spotlight/Raycast, per-app config JSON, polish | 4 ngày |
| 7 | Build script DMG ad-hoc, GitHub Actions, viết README | 3 ngày |

Notarize/Developer ID là phase riêng, sau khi có account.

## 6. Open questions (cần resolve trước khi code phase 0)

- [ ] **License**: chọn A (clean-room MIT) / B (port GPL) / C (hybrid)?
- [ ] **Scope MVP**: feature nào vào MVP (xem bảng 3.2)?
- [ ] **Distribution**: có Apple Developer account chưa? Public release hay tự dùng?
- [ ] **Tên hiển thị**: dkey, DKey, hay tên khác?
- [ ] **Bundle ID**: `com.datnm555.dkey`? hoặc khác?
- [ ] **Phím chuyển mặc định**: theo MKey là ⌥Z. Giữ hay đổi?
- [ ] **Target macOS tối thiểu**: 14 (giống MKey), 15, hay 26?

## 7. Tài liệu tham chiếu sau

- Spec Telex/VNI: Wikipedia "Vietnamese input method".
- Unicode tổ hợp tiếng Việt: chuẩn Unicode 15+, NFD/NFC.
- Bảng mã TCVN3/VNI/VIQR/VPS: tra cứu công khai.
- Apple docs: `CGEventTap`, `AXUIElement`, `SMAppService`, `MenuBarExtra`.
- Code tham chiếu cấu trúc (KHÔNG đọc chi tiết nếu chọn clean-room): `../mkey/`.

---

**Next step khi quay lại:** trả lời các open question ở mục 6, đặc biệt 6.1 license. Sau đó tôi sẽ viết spec implementation chi tiết qua `superpowers:writing-plans`.
