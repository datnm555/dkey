# Đưa dkey ngang tính năng mkey — Thiết kế & lộ trình PR

Ngày: 2026-07-10
Nguồn tham chiếu: https://github.com/maclifevn/mkey (bộ gõ tiếng Việt macOS, engine C++ OpenKey + SwiftUI)

## Bối cảnh

`dkey` và `mkey` là hai bản hiện thực của cùng ý tưởng (bộ gõ tiếng Việt cho macOS):

| | mkey | dkey |
|---|---|---|
| Engine gõ | C++ OpenKey + cầu nối ObjC++ (`MKBridge.mm`, `MKEngineHook.mm`) | **Swift thuần**, có bộ test parity đầy đủ |
| UI | SwiftUI (Typing/Convert/Macro/Clipboard/System/About/Welcome) | SwiftUI, đơn giản hơn nhiều, nhiều mục để "placeholder" |
| Clipboard manager | Có (lịch sử/ghim/xem trước ảnh/global hotkey) | Chưa có |
| UpdateChecker | Có (GitHub API) | Chỉ mở trang releases |

Quyết định của người dùng:
1. **Giữ engine Swift + test parity của dkey** (không thay bằng C++).
2. Đợt này làm **Nhóm A** (thuần app-layer) chạy thật; **Nhóm B** (cần engine/platform) để **placeholder disabled "sắp có"**.
3. **Bám sát mkey** về nhãn/bố cục/thứ tự/kích thước — kể cả phải bỏ vài chỗ dkey đang làm khác.

## Nguyên tắc

1. **Không nút giả.** Control bật được → chạy thật. Chưa có engine → hàng disabled + nhãn "sắp có", ẩn khỏi VoiceOver (theo nếp `SystemExtras.placeholderRows`).
2. **Test-first.** Mỗi PR tách logic thuần (so version, encode/decode, convert, lọc) để viết unit test trước.
3. **Sau khi thêm file mới:** chạy `xcodegen generate`; sau khi merge/checkout dọn `build/` trước khi build lại (xem `memory/`).
4. **Bám mkey** cho nhãn tiếng Việt, thứ tự nhóm, kích thước cửa sổ, icon.

## Phân nhóm tính năng

### Nhóm A — thuần app-layer, làm thật đợt này
- Clipboard manager (lịch sử/ghim/xem trước ảnh/global hotkey ⌃V — cần `Carbon.framework`).
- UpdateChecker thật (GitHub API `datnm555/dkey`) + mục "Cập nhật" ở Hệ thống.
- Giới thiệu: thẻ tính năng + tác giả + version pills.
- Welcome: glow icon + chấm nhấp nháy chờ quyền.
- Khung app: tab Clipboard, StatusIcon vẽ đặc, cửa sổ 820×560, menu bar đầy đủ, sidebar có icon app + badge quyền.
- Chuyển mã: nút chuyển-qua-clipboard + alert (dùng `ConvertTool.swift` Swift sẵn có).
- Gõ tắt: đồng bộ iCloud Drive (`MacroCloudSync`).
- Bố cục màn Gõ khớp 6 nhóm của mkey.

### Nhóm B — cần engine/platform (đợt này = placeholder)
Live code-table cho gõ (TelexEngine đang hardcode `codeTableUnicode` tại `TelexEngine.swift:1182,1190`) · kiểm tra chính tả + khôi phục phím + cho phép ZFWJ · gõ nhanh Telex + phụ âm đầu/cuối nhanh · bỏ dấu tự do · tự viết hoa đầu câu · Simple Telex 1&2 · sửa lỗi trình duyệt/Chromium · hỗ trợ AX Spotlight/Raycast + danh sách app · gửi phím từng bước · nhớ bảng mã theo app.

→ Sẽ có spec engine riêng sau.

## Quy ước dùng chung
- `AppStyle`: `contentMaxWidth = 680`, `controlCornerRadius = 7`, `cardCornerRadius = 8`.
- Màu: dùng bảng `Theme.swift` hiện có (`dkWindowBg/dkPanel/dkText/dkSecondary/dkAccent/dkSuccess`), bổ sung khi thiếu.
- Component: `SectionCard`, `ToggleRow` (đã có) + thêm `InfoRow`, `InfoPill`, `HotkeyEditor` (keycap).

## Lộ trình PR

Mỗi PR review & merge độc lập. `⚠️` = bám mkey nghĩa là bỏ/đổi tính năng dkey đang có (đã được người dùng đồng ý).

### PR1 — Nền giao diện
- `AppStyle.swift` (mới): hằng số + `settingsFormStyle()`.
- `StatusIcon.swift`: vẽ **đặc** (fill), màu xanh `#0066AB` (color) / đen (gray/template), chữ trắng 14pt `.medium`, bo góc 2.
- `DkeyApp.swift`: cửa sổ **820×560**, `.windowStyle(.hiddenTitleBar)`.
- `SettingsRootView.swift`: sidebar có app icon 64, header "CÀI ĐẶT", rộng 192, badge trạng thái quyền Trợ năng.
- Test: `AppStyleTests`. Build + smoke.

### PR2 — UpdateChecker + mục "Cập nhật"
- `UpdateChecker.swift` (mới): endpoint `https://api.github.com/repos/datnm555/dkey/releases/latest`; status enum idle/checking/available/upToDate/failed; `check(manual:)`, `autoCheckIfDue()` (24h), `isNewer(_:than:)`, `numericComponents(_:)`; keys `autoCheckUpdate`, `lastUpdateCheck`.
- `SystemView.swift`: thêm section "Cập nhật" (toggle auto-check, status, "Kiểm tra ngay", "Xem bản mới") + 2 placeholder "Tương thích nâng cao" (gửi phím từng bước, tương thích layout khác).
- Test: `UpdateCheckerTests` cho `isNewer`/`numericComponents` (thuần).

### PR3 — Giới thiệu (About) — phụ thuộc PR2
- `AboutView.swift`: thẻ tính năng `InfoRow` ×4 (Bộ gõ/Tương thích/Tiện ích/Hiệu năng), tác giả, version pills; nút "Kiểm tra cập nhật" → mở tab Hệ thống + `UpdateChecker.shared.check(manual:true)`.
- `SettingsComponents.swift`: thêm `InfoRow`, `InfoPill`.

### PR4 — Welcome — phụ thuộc PR1
- `OnboardingView.swift`: glow icon (Circle blur) + chấm cam nhấp nháy "Đang chờ bạn bật quyền…", bám layout mkey. Giữ lối thoát an toàn.

### PR5 — Màn Gõ — phụ thuộc PR1
- `TypingSettingsView.swift`: 6 nhóm khớp mkey. Wiring thật: kiểu gõ (Telex/VNI), kiểu bỏ dấu, phím chuyển. Placeholder: chính tả (5), gõ nhanh (4), tương thích (4), AX (1 + danh sách).
- `TypingExtras.swift`: mở rộng `placeholderRows`.
- `HotkeyEditor.swift` (mới): port keycap badge từ mkey (bỏ ref `MKBridge`, dùng codec dkey).
- Test: `TypingExtrasTests`, bit-encode hotkey.

### PR6 — Chuyển mã — độc lập
- `ConvertView.swift`: bám mkey — pickers Từ/Sang bảng mã + "Đảo chiều", Picker kiểu chữ (radio), toggle bỏ dấu thanh, HotkeyEditor (đăng ký hotkey để ở PR9), toggle "Thông báo khi xong", nút **"Chuyển mã clipboard"** (đọc `NSPasteboard` → `ConvertTool.convert` → ghi lại) + alert. ⚠️ **Bỏ ô nhập/kết quả trực tiếp**.
- `ConvertTool.swift`: sửa nhãn `.sentence` → "Hoa chữ cái đầu câu".
- `ClipboardConvert.swift` (mới, thuần): `func convertPasteboardString(_:from:to:...) -> String?` để test.
- Test: `ClipboardConvert`, nhãn CaseMode.

### PR7 — Gõ tắt + iCloud — độc lập
- `MacroView.swift`: bám mkey — 3 toggle (bật gõ tắt / trong English / tự hoa), section "Đồng bộ" iCloud + status + "Đồng bộ ngay", ô thêm/sửa inline + focus, bảng 2 cột, Nhập/Xuất. ⚠️ **Bỏ ô tìm kiếm** (giữ helper `MacroFilter` + test).
- `MacroCloudSync.swift` (mới): iCloud Drive coordinated read/write, dùng `state.macros`, tên file `dkeyMacroData`, notification `.dkMacroCloudSyncDidImport`, status "iCloud không khả dụng" khi thiếu container.
- `dkey.entitlements` + `project.yml`: iCloud container (chỉ hoạt động khi có Team; ad-hoc → hiện không khả dụng, không crash).
- Test: `MacroCloudSync` serialize/merge (thuần).

### PR8a — Clipboard lõi — độc lập
- `project.yml`: +`Carbon.framework`.
- `Clipboard/GlobalHotKey.swift` (mới): wrapper Carbon `RegisterEventHotKey`; bitfield `0x[char:24][mods:4][keyCode:8]` (⌃0x100/⌥0x200/⌘0x400/⇧0x800).
- `Clipboard/ClipItem.swift` (mới): model Codable (id, isImage, text, htmlText, imageFile, filePaths, date, sourceApp, pinned).
- `Clipboard/ClipboardManager.swift` (mới): polling NSPasteboard 0.25s, ghim/trim theo maxItems (ghim không tính), persist JSON UserDefaults + PNG `~/Library/Application Support/dkey/clipboard/`. **Chưa có cửa sổ.**
- Test: `GlobalHotKeyTests` (bitfield), `ClipboardManagerTests` (trim/pin/persist roundtrip, thuần — không cần pasteboard sống).

### PR8b — Clipboard UI — phụ thuộc PR8a
- `Clipboard/ClipboardPicker.swift` (mới): `NSPanel` non-activating + monitor phím (↑↓ chọn, ⏎/Tab dán, ⌘P ghim, 1–9 chọn nhanh, Esc, gõ để lọc), xem trước ảnh khi hover.
- `Views/ClipboardView.swift` (mới): toggle bật, slider maxItems 10–100, HotkeyEditor, pin-on-top, auto-hide, "Đặt lại vị trí cửa sổ".
- `AppState.swift`/`DkeySettings.swift`: +cài đặt clipboard, +`.clipboard` vào `SettingsPage` (thứ tự: typing/macro/convert/**clipboard**/system/about).
- `SettingsRootView.swift`: case `.clipboard` → `ClipboardView()`.
- `DkeyApp.swift`: khởi động manager lúc launch.
- Test: `ClipboardFilter` (lọc bỏ dấu, không phân biệt hoa thường).

### PR9 — Menu bar — phụ thuộc PR6, 8a, 8b
- Overhaul menu bar khớp mkey: toggle "Tiếng Việt" + hotkey, Picker kiểu gõ (Simple Telex disabled), Picker **bảng mã (placeholder disabled)**, "Chuyển mã nhanh" (Carbon hotkey), "Công cụ chuyển mã…", "Gõ tắt…", "Lịch sử Clipboard", "Bảng điều khiển…", "Giới thiệu…", "Thoát".
- Đăng ký hotkey chuyển-mã-nhanh (tái dùng `GlobalHotKey`).

## Rủi ro
- **iCloud (PR7):** ký ad-hoc không có Team → entitlement iCloud không chạy thật; UI hiện "iCloud không khả dụng" trung thực, không crash.
- **Carbon ⌃V (PR8a):** hotkey toàn cục có thể đụng app khác → cho đổi phím trong settings.
- **StatusIcon (PR1):** đổi hình icon menu bar người dùng thấy hằng ngày — cần chốt thẩm mỹ.
- **Bỏ tính năng dkey (PR6/PR7):** ô nhập trực tiếp Chuyển mã + ô tìm kiếm Gõ tắt bị gỡ theo hướng bám mkey.

## Ngoài phạm vi (đợt sau)
Toàn bộ Nhóm B: hiện thực engine/platform thật cho chính tả, gõ nhanh, live code-table, Simple Telex, sửa lỗi trình duyệt, AX Spotlight, gửi phím từng bước, nhớ bảng mã theo app. Mỗi mảng có spec + test parity riêng.
