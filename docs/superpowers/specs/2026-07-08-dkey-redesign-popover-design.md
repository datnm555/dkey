# dkey Redesign — Screen ② Bảng điều khiển chính (popover) Design Spec

**Ngày:** 2026-07-08
**Trạng thái:** Đã brainstorm & duyệt design — chờ user review spec trước khi viết plan.
**Bối cảnh:** Redesign UI 6 màn theo `DKey Mockups.standalone.html`, làm **tuần tự per-screen**. Màn ① (Foundation + Onboarding) đã xong + merge `main`. Đây là **sub-project 2/6: redesign menu-bar dropdown thành popover giàu** theo mockup screen 1a.

---

## 1. Mục tiêu

Thay dropdown menu-bar hiện tại (native `MenuContent`: `Toggle`/`Button` thô) bằng **popover tùy biến** đúng mockup: header DKey, card công tắc tiếng Việt (kèm phụ đề phím chuyển), hàng **Kiểu gõ** dạng segmented, hàng **Bảng mã** dạng dropdown, footer Cài đặt/Thoát. Dùng chung `Theme` (màn ①).

### Phạm vi — TRONG
- **Đổi kiểu MenuBarExtra sang `.window`** (`.menuBarExtraStyle(.window)`) để render SwiftUI tùy biến thay cho native menu.
- **`ControlPanelView`** (view mới) — nội dung popover, style theo `Theme`:
  - **Header**: icon app + "DKey" + tagline phụ. *(Bỏ 3 chấm traffic-light của mockup — đó là khung "mini-window" của gallery, không phải UI thật của popover menu-bar.)*
  - **Card công tắc chính**: title "Tiếng Việt", phụ đề "Phím chuyển nhanh `<hotkey>`" (hiển thị phím chuyển đang cấu hình qua `AppState.hotkeyDescription(switchKeyStatus)`), `Toggle` bind `isVietnamese`.
  - **Hàng Kiểu gõ**: segmented tùy biến `[ Telex │ VNI │ Simple Telex ]`; Telex/VNI bind `inputMethod` (live), **Simple Telex làm mờ + không bấm được** (placeholder, chưa có backing).
  - **Hàng Bảng mã**: control kiểu dropdown hiển thị "Unicode (dựng sẵn)", **disabled** (placeholder, chưa có backing).
  - **Footer**: "Cài đặt…" (mở window `settings`) + "Thoát" (`NSApp.terminate`). Vì `.window` không có native menu, popover phải tự mang 2 nút này.
- **Logic thuần test được**: `ControlPanel.inputMethodSegments` — trả về 3 segment `(label, method?, enabled)` cho Kiểu gõ.

### Phạm vi — HOÃN (sub-project sau)
- **Simple Telex** như một input method thật (engine): remap phím + cờ + parity corpus. Ở đây chỉ là segment **disabled**.
- **Bảng mã sống** (re-encode output TCVN3/VNI-Windows… theo từng phím): đụng đường synthesis + parity nhiều bảng mã. Ở đây chỉ là control **disabled**.
- Các màn ③–⑥ (Kiểu gõ, Gõ tắt, Chuyển mã, Hệ thống+Giới thiệu).

### Success criteria
1. Bấm icon menu-bar → mở **popover tùy biến** (không phải native menu), style khớp `Theme`/mockup.
2. Công tắc "Tiếng Việt" bật/tắt đổi `isVietnamese` (icon menu-bar phản ánh); phụ đề hiện đúng phím chuyển đang cấu hình.
3. Segmented Kiểu gõ: bấm Telex/VNI đổi `inputMethod` live; **Simple Telex mờ, bấm không đổi gì**.
4. Bảng mã hiển thị "Unicode (dựng sẵn)" **disabled**.
5. Footer: "Cài đặt…" mở window settings + activate; "Thoát" thoát app.
6. Không đụng engine; `DkeySettings`/`AppState` model không đổi; toàn bộ test hiện có (137) vẫn xanh + test mới cho `inputMethodSegments`.

---

## 2. Quyết định kiến trúc

- **`.window` style là bắt buộc** cho độ trung thực mockup: native `.menu` không render được segmented control, card, dropdown. Phương án giữ `.menu` bị loại.
- **Tách logic thuần khỏi view**: danh sách segment (label + method + enabled) là hàm thuần, test được; view + wiring build-verified + smoke (theo pattern màn ①).
- **Segmented tùy biến (HStack nút)** thay vì `Picker(.segmented)`: SwiftUI segmented `Picker` không disable được từng segment, mà ta cần Simple Telex mờ. Inline trong `ControlPanelView`, **không** tạo component tái dùng (YAGNI).
- **Không đụng engine**, không đổi `DkeySettings`/`AppState` fields — mọi thứ ở `Sources/App`.
- Placeholder (Simple Telex, Bảng mã) **disabled** để layout khớp mockup nhưng không giả vờ hoạt động.

---

## 3. Thay đổi theo module (`Sources/App/`)

| File | Trách nhiệm |
|---|---|
| `ControlPanel.swift` *(mới)* | Logic thuần: `enum ControlPanel { struct Segment { label: String; method: InputMethod?; enabled: Bool } ; static var inputMethodSegments: [Segment] }`. Telex/VNI enabled (method != nil), Simple Telex disabled (method nil, enabled false). |
| `Views/ControlPanelView.swift` *(mới)* | SwiftUI popover: header, card công tắc, hàng Kiểu gõ (segmented tùy biến từ `inputMethodSegments`), hàng Bảng mã (disabled), footer Cài đặt/Thoát. Bind `AppState`. |
| `DkeyApp.swift` *(sửa)* | `MenuBarExtra { ControlPanelView() } label: { MenuBarLabel() }` + `.menuBarExtraStyle(.window)`. Xóa `MenuContent` cũ (thay bằng `ControlPanelView`). Giữ nguyên window `settings`/`onboarding`, `MenuBarLabel`, delegate. |

Không đổi `AppState.swift`, `DkeySettings.swift`, `Theme.swift`, engine.

---

## 4. Luồng popover

```
Bấm icon menu-bar (MenuBarLabel) → MenuBarExtra(.window) mở ControlPanelView
ControlPanelView (bind AppState):
  Card công tắc: Toggle(isOn: $state.isVietnamese)
    phụ đề = "Phím chuyển nhanh " + AppState.hotkeyDescription(state.switchKeyStatus)
  Kiểu gõ: ForEach(ControlPanel.inputMethodSegments)
    segment.enabled == false → mờ, không bấm được (Simple Telex)
    segment.method != nil → bấm set state.inputMethod = method (highlight khi == hiện tại)
  Bảng mã: hộp "Unicode (dựng sẵn)" .disabled(true)
  Footer:
    "Cài đặt…" → openWindow("settings") + NSApp.activate
    "Thoát"    → NSApp.terminate(nil)
```

---

## 5. Testing
- `ControlPanelTests`:
  - `inputMethodSegments.count == 3`; labels == `["Telex","VNI","Simple Telex"]`.
  - Telex/VNI: `enabled == true` và `method` khớp (`.telex`/`.vni`); Simple Telex: `enabled == false`, `method == nil`.
- `ControlPanelView` + MenuBarExtra `.window`: BUILD SUCCEEDED + smoke thủ công (deferred user: mở popover; toggle VN; đổi Telex↔VNI; Simple Telex/Bảng mã mờ không tác dụng; Cài đặt mở settings; Thoát thoát).
- Không hồi quy engine (137 test cũ vẫn xanh).

## 6. YAGNI
Chỉ popover + logic segment. Không component library, không build Simple Telex/Bảng mã sống, không đụng các tab settings.

## 7. Self-review
- **Phạm vi:** 1 sub-project nhỏ (đổi style + 1 view + 1 helper thuần). Đủ cho 1 plan. ✅
- **Nhất quán:** module (§3) ↔ luồng (§4) ↔ test (§5). ✅
- **Không placeholder mơ hồ:** control disabled có lý do (chưa có backing), footer/hotkey cụ thể. ✅
- **Rủi ro:** `.window` style đổi cách popover đóng/mở (không còn dismiss kiểu native menu) — footer tự mang Cài đặt/Thoát để bù; segmented tùy biến cần đảm bảo Simple Telex thật sự không nhận tap.
