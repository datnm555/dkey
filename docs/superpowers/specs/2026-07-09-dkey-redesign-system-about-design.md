# dkey Redesign — Screen ⑥ Hệ thống + Giới thiệu Design Spec

**Ngày:** 2026-07-09
**Trạng thái:** Đã brainstorm & duyệt design — chờ user review spec trước khi viết plan.
**Bối cảnh:** Redesign UI 6 màn theo `DKey Mockups.standalone.html`, tuần tự per-screen. ①②③④ merged, ⑤ đang ở PR #2. Đây là **sub-project 6/6 (màn cuối): restyle 2 tab Hệ thống + Giới thiệu** theo mockup System/About screen.

---

## 1. Mục tiêu

Restyle 2 tab cuối — `SystemView` (Hệ thống) và `AboutView` (Giới thiệu) — sang phong cách card (dùng lại `SectionCard`/`ToggleRow`). Wire "Kiểm tra cập nhật" mở trang GitHub Releases (thật). Hiện 3 feature chưa có backing dưới dạng **placeholder disabled**. Không đụng engine/model.

### Phạm vi — TRONG
- **`SystemExtras.placeholderRows`** (logic thuần, test được): 2 hàng toggle placeholder disabled — "Sửa lỗi autocorrect trên trình duyệt" và "Ghi nhớ bảng mã theo ứng dụng" (subtitle "Hữu ích với Photoshop, CAD… dùng VNI, TCVN3"). Shape `(title, subtitle?, enabled: false)` như `TypingExtras`.
- **`SystemView`** viết lại: 2 `SectionCard` + nút reset:
  - **Card "Hệ thống"**: `ToggleRow` cho toggle backed — "Khởi động cùng macOS" ($runOnStartup), "Hiện cửa sổ Cài đặt khi khởi động" ($showUIOnStartup), "Biểu tượng đơn sắc trên menu bar" ($grayIcon), "Hiện biểu tượng ở Dock" ($showIconOnDock); + placeholder disabled "Sửa lỗi autocorrect trên trình duyệt" (từ `SystemExtras.placeholderRows[0]`).
  - **Card "Cài đặt theo ứng dụng"**: `ToggleRow` backed "Chuyển chế độ thông minh" (subtitle "Tự nhớ chế độ Việt/Anh của từng ứng dụng khi chuyển qua lại", $useSmartSwitchKey); + placeholder disabled "Ghi nhớ bảng mã theo ứng dụng" (từ `SystemExtras.placeholderRows[1]`); + **1 hàng dimmed placeholder** cho danh sách per-app ("Cấu hình từng ứng dụng — sắp có", inert).
  - Nút **"Khôi phục cài đặt mặc định"** (destructive) + `confirmationDialog` (giữ nguyên hành vi `state.resetToDefaults()`).
  - Nền `Color.dkWindowBg`.
- **`AboutView`** viết lại thành card: icon app + "dkey" + "Bộ gõ Tiếng Việt cho macOS" + "Phiên bản \(AppInfo.displayVersion)" + credit GPL/OpenKey + nút "Mã nguồn dkey"/"OpenKey" (giữ) + nút mới **"Kiểm tra cập nhật"** mở `https://github.com/datnm555/dkey/releases`.

### Phạm vi — HOÃN (sub-project riêng, sau)
- **Sửa lỗi autocorrect trên trình duyệt** (engine/tap) — placeholder disabled.
- **Ghi nhớ bảng mã theo ứng dụng** (cần live Bảng mã, đã hoãn ở ②) — placeholder disabled.
- **Danh sách/editor per-app** (Ps/Skype/Terminal/Xcode) — `SmartSwitch` nhớ ngôn ngữ per-app nội bộ nhưng chưa có UI editor + chưa có per-app code table — placeholder dimmed.
- **Cập nhật tự động (Sparkle)** — "Kiểm tra cập nhật" chỉ mở Releases (thủ công), không auto-updater.

### Success criteria
1. 2 tab hiển thị card style mockup (nền/panel/màu theo Theme).
2. Toggle backed vẫn hoạt động (runOnStartup/showUIOnStartup/grayIcon/showIconOnDock/useSmartSwitchKey); reset vẫn mở dialog + khôi phục.
3. 3 feature chưa backing hiện **mờ + inert** (2 toggle + 1 hàng per-app).
4. "Kiểm tra cập nhật" mở đúng trang Releases; các link cũ (dkey/OpenKey) vẫn mở.
5. Không đụng engine; `AppState`/`DkeySettings` model không đổi; test cũ (149) vẫn xanh + test mới `SystemExtras`.

---

## 2. Quyết định kiến trúc

- **Tách logic thuần khỏi view**: `SystemExtras.placeholderRows` là data thuần, test được; view build-verified + smoke (pattern ②③).
- **Dùng lại `SectionCard`/`ToggleRow`** cho cả toggle thật (backed) lẫn placeholder (enabled:false) — không component mới (YAGNI). Per-app placeholder là 1 hàng dimmed inline (không phải toggle) → không nhét vào `placeholderRows`.
- **"Kiểm tra cập nhật" = mở Releases URL** (thật, rẻ) thay vì Sparkle — không hạ tầng update, không disabled.
- **Giữ nguyên binding + reset flow**: toggle bind đúng `AppState`, `resetToDefaults()` + `confirmationDialog` không đổi hành vi.
- **Không đụng engine/model.** 2 view + 1 helper thuần.

---

## 3. Thay đổi theo module (`Sources/App/`)

| File | Trách nhiệm |
|---|---|
| `SystemExtras.swift` *(mới)* | Logic thuần: `enum SystemExtras { struct Row: Equatable { title: String; subtitle: String?; enabled: Bool } ; static var placeholderRows: [Row] }`. 2 hàng, `enabled == false`; chỉ "Ghi nhớ bảng mã…" có subtitle. |
| `Views/SystemView.swift` *(viết lại)* | `ScrollView`/`VStack` 2 `SectionCard` (Hệ thống, Cài đặt theo ứng dụng) + toggle backed (`ToggleRow`) + 2 placeholder toggle (từ `SystemExtras`) + 1 hàng per-app dimmed + nút reset + `confirmationDialog`. Nền `dkWindowBg`. Giữ `@EnvironmentObject state`, `@State confirmingReset`. |
| `Views/AboutView.swift` *(viết lại)* | Card icon/tên/version/credit/links + nút "Kiểm tra cập nhật" mở `dkey/releases`. Giữ `AppInfo.displayVersion`, link dkey/OpenKey. |

Không đổi `AppState.swift`, `DkeySettings.swift`, `SmartSwitch.swift`, `SettingsComponents.swift`, `Theme.swift`, `AppInfo.swift`, `SettingsRootView.swift`, engine.

---

## 4. Luồng

```
SettingsRootView → detail → SystemView / AboutView (không đổi host)
SystemView (@State confirmingReset):
  SectionCard("Hệ thống") {
    ToggleRow "Khởi động cùng macOS" $runOnStartup
    ToggleRow "Hiện cửa sổ Cài đặt khi khởi động" $showUIOnStartup
    ToggleRow "Biểu tượng đơn sắc trên menu bar" $grayIcon
    ToggleRow "Hiện biểu tượng ở Dock" $showIconOnDock
    ToggleRow(placeholderRows[0]: "Sửa lỗi autocorrect trên trình duyệt", isOn:.constant(false), enabled:false)
  }
  SectionCard("Cài đặt theo ứng dụng") {
    ToggleRow "Chuyển chế độ thông minh" (subtitle …) $useSmartSwitchKey
    ToggleRow(placeholderRows[1]: "Ghi nhớ bảng mã theo ứng dụng", subtitle …, isOn:.constant(false), enabled:false)
    <hàng dimmed> "Cấu hình từng ứng dụng — sắp có" (inert)
  }
  Button("Khôi phục cài đặt mặc định", destructive) → confirmingReset=true
  .confirmationDialog(... "Khôi phục" → state.resetToDefaults() / "Huỷ")

AboutView:
  SectionCard/VStack { icon · dkey · "Bộ gõ Tiếng Việt cho macOS" · "Phiên bản \(AppInfo.displayVersion)" ·
    credit GPL/OpenKey · [Mã nguồn dkey][OpenKey][Kiểm tra cập nhật→releases] }
```

---

## 5. Testing
- `SystemExtrasTests`:
  - `placeholderRows.count == 2`; titles == `["Sửa lỗi autocorrect trên trình duyệt","Ghi nhớ bảng mã theo ứng dụng"]`.
  - mọi row `enabled == false`.
  - chỉ row[1] có `subtitle == "Hữu ích với Photoshop, CAD… dùng VNI, TCVN3"`; row[0] `subtitle == nil`.
- `SystemView`/`AboutView` restyle: BUILD SUCCEEDED + smoke thủ công (deferred user: toggle backed chạy; 3 placeholder mờ inert; reset dialog; Kiểm tra cập nhật mở Releases; link cũ mở).
- Không hồi quy: 149 test cũ vẫn xanh.

## 6. YAGNI
Chỉ 1 helper thuần + viết lại 2 view (dùng lại primitive ③). Không component mới, không auto-updater, không per-app editor, không đổi model/engine.

## 7. Self-review
- **Phạm vi:** 1 sub-project (1 helper + 2 view rewrite). Đủ 1 plan (3 task nhỏ). ✅
- **Nhất quán:** module (§3) ↔ luồng (§4) ↔ test (§5). ✅
- **Không placeholder mơ hồ:** placeholder disabled có lý do (chưa backing); "Kiểm tra cập nhật" = Releases URL cụ thể; copy verbatim. ✅
- **Rủi ro:** per-app placeholder là 1 hàng dimmed (không toggle) → giữ inert bằng `.allowsHitTesting(false)`/opacity; reset `confirmationDialog` cần bind đúng `@State`. Không rủi ro engine.
