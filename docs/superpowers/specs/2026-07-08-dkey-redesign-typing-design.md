# dkey Redesign — Screen ③ Kiểu gõ (settings tab) Design Spec

**Ngày:** 2026-07-08
**Trạng thái:** Đã brainstorm & duyệt design — chờ user review spec trước khi viết plan.
**Bối cảnh:** Redesign UI 6 màn theo `DKey Mockups.standalone.html`, tuần tự per-screen. ① Onboarding + ② Popover đã xong + merge `main`. Đây là **sub-project 3/6: redesign tab Kiểu gõ** trong cửa sổ Settings, theo mockup screen 1b.

---

## 1. Mục tiêu

Viết lại `TypingSettingsView` (đang là `Form` grouped thô) thành phong cách **card + toggle-row** theo mockup, dùng `Theme`. Giữ 3 control đang chạy (Kiểu gõ, Kiểu bỏ dấu, Phím chuyển) và thêm mục "Gõ tiếng Việt" gồm **5 hàng toggle placeholder (disabled)**.

Đồng thời tạo **2 primitive tái dùng** cho các tab ④⑤⑥ sau: `SectionCard` + `ToggleRow`.

### Phạm vi — TRONG
- **`SectionCard`** (view tái dùng): panel bo góc có tiêu đề, chứa content bất kỳ. Nền `Color.dkPanel`, tiêu đề `Color.dkSecondary` (uppercase nhỏ). Dùng cho ③, tái dùng ④⑤⑥.
- **`ToggleRow`** (view tái dùng): title + subtitle (tùy chọn) + `Toggle` bên phải; cờ `enabled`. Khi `enabled == false` → mờ + inert (bind `.constant(false)`, `.disabled(true)`) — đúng pattern placeholder của màn ②.
- **`TypingExtras.placeholderRows`** (logic thuần): `[Row]` (title, subtitle?, `enabled: false`) mô tả 5 hàng hoãn. View render `ToggleRow` từ đây.
- **`TypingSettingsView`** (viết lại): `ScrollView` chứa `VStack` 2 `SectionCard`:
  - Card **"Kiểu gõ"**: Kiểu gõ `[Telex│VNI]` (segmented, bind `inputMethod`), Kiểu bỏ dấu `(Mới/Cũ)` (radio, bind `useModernOrthography`), Phím chuyển (`KeyRecorderField`, bind `switchKeyStatus`) — 3 control hiện có, restyle.
  - Card **"Gõ tiếng Việt"**: 5 `ToggleRow` từ `TypingExtras.placeholderRows`, tất cả disabled: Kiểm tra chính tả · Khôi phục phím nếu từ sai · Viết hoa chữ cái đầu câu · Gõ nhanh Telex *(subtitle "cc = ch, gg = gi, kk = kh, nn = ng…")* · Cho phép f, z, w, j làm phụ âm đầu.

### Phạm vi — HOÃN (sub-project engine riêng, sau)
Cả 5 feature engine: **Kiểm tra chính tả** (`vCheckSpelling`), **Khôi phục phím nếu sai** (`vRestoreIfWrongSpelling` — cần undo-stack, khó), **Viết hoa đầu câu**, **Gõ nhanh Telex** (`vQuickTelex`), **Cho phép f/z/w/j** (gắn với spell-check). Ở đây chỉ là hàng **disabled**. Mỗi feature sẽ có sub-project engine riêng (oracle + parity corpus).
Không đụng "Bảng mã sống" (đã hoãn ở ②), không component library đầy đủ (chỉ 2 primitive ③ cần), không đổi các tab ④⑤⑥.

### Success criteria
1. Tab Kiểu gõ hiển thị 2 card style mockup (nền/panel/màu theo `Theme`).
2. 3 control cũ vẫn hoạt động: đổi Telex↔VNI (`inputMethod`), Mới↔Cũ (`useModernOrthography`), ghi phím chuyển (`switchKeyStatus`).
3. 5 hàng "Gõ tiếng Việt" hiển thị đúng title/subtitle, **mờ + không bấm được** (không đổi state nào).
4. `SectionCard`/`ToggleRow` là view tái dùng, không phụ thuộc AppState (nhận data qua tham số/binding).
5. Không đụng engine; `DkeySettings`/`AppState` model không đổi; toàn bộ test cũ (140) vẫn xanh + test mới cho `TypingExtras.placeholderRows`.

---

## 2. Quyết định kiến trúc

- **2 primitive tái dùng, không phải library**: ③–⑥ chung ngôn ngữ card/row. Chỉ tạo `SectionCard` + `ToggleRow` (2 view ③ dùng trực tiếp); biến thể khác thêm dần khi ④⑤⑥ cần (YAGNI). Phương án inline-rồi-tách-sau bị loại vì pattern rõ ràng dùng lại ở 4 tab.
- **Tách logic thuần khỏi view**: `TypingExtras.placeholderRows` là data thuần, test được; view build-verified + smoke.
- **Placeholder inert**: 5 hàng disabled dùng `.constant(false)` + `.disabled(true)` — không thêm field `DkeySettings`, không đổi model (đúng quyết định "hoãn cả 5").
- **View tái dùng độc lập AppState**: `SectionCard`/`ToggleRow` nhận `title`/`subtitle`/`isOn`/`enabled` qua tham số — test/độc lập được, không coupling.
- **Không đụng `SettingsRootView`** (host các tab khác chưa redesign): `TypingSettingsView` tự bọc `ScrollView` + nền `Color.dkWindowBg` lấp không gian; thống nhất nền toàn cửa sổ để dành polish sau khi cả 5 tab xong.
- **Không đụng engine.**

---

## 3. Thay đổi theo module (`Sources/App/`)

| File | Trách nhiệm |
|---|---|
| `Views/SettingsComponents.swift` *(mới)* | `struct SectionCard<Content: View>: View { title: String; content }` + `struct ToggleRow: View { title: String; subtitle: String?; isOn: Binding<Bool>; enabled: Bool }`. Style theo `Theme`. Tái dùng ③④⑤⑥. |
| `TypingExtras.swift` *(mới)* | Logic thuần: `enum TypingExtras { struct Row: Equatable { title: String; subtitle: String?; enabled: Bool } ; static var placeholderRows: [Row] }`. 5 hàng, tất cả `enabled == false`; chỉ "Gõ nhanh Telex" có subtitle. |
| `Views/TypingSettingsView.swift` *(viết lại)* | `ScrollView { VStack { SectionCard("Kiểu gõ"){ 3 control cũ } ; SectionCard("Gõ tiếng Việt"){ ForEach placeholderRows → ToggleRow(disabled) } } }`. Nền `Color.dkWindowBg`. |

Không đổi `AppState.swift`, `DkeySettings.swift`, `SettingsRootView.swift`, `Theme.swift`, engine.

---

## 4. Luồng

```
SettingsRootView (không đổi) → detail → TypingSettingsView
TypingSettingsView:
  ScrollView { VStack(spacing:16) {
    SectionCard(title: "Kiểu gõ") {
      segmented Kiểu gõ  → $state.inputMethod (Telex/VNI)
      radio Kiểu bỏ dấu  → $state.useModernOrthography (Mới/Cũ)
      Phím chuyển        → KeyRecorderField(status: $state.switchKeyStatus)
    }
    SectionCard(title: "Gõ tiếng Việt") {
      ForEach TypingExtras.placeholderRows { row in
        ToggleRow(title: row.title, subtitle: row.subtitle,
                  isOn: .constant(false), enabled: row.enabled)  // enabled=false → mờ, inert
      }
    }
  } }.background(Color.dkWindowBg)
```

---

## 5. Testing
- `TypingExtrasTests`:
  - `placeholderRows.count == 5`.
  - titles == `["Kiểm tra chính tả","Khôi phục phím nếu từ sai","Viết hoa chữ cái đầu câu","Gõ nhanh Telex","Cho phép f, z, w, j làm phụ âm đầu"]` (đúng thứ tự).
  - mọi row `enabled == false`.
  - chỉ "Gõ nhanh Telex" có `subtitle == "cc = ch, gg = gi, kk = kh, nn = ng…"`; các row khác `subtitle == nil`.
- `SectionCard`/`ToggleRow`/`TypingSettingsView`: BUILD SUCCEEDED + smoke thủ công (deferred user: 2 card hiển thị; 3 control cũ hoạt động; 5 hàng mờ bấm không tác dụng).
- Không hồi quy engine (140 test cũ vẫn xanh).

## 6. YAGNI
Chỉ 2 primitive ③ cần + 1 helper thuần + viết lại 1 view. Không build engine feature nào, không đổi model, không đụng tab khác.

## 7. Self-review
- **Phạm vi:** 1 sub-project (2 view tái dùng + 1 helper + rewrite 1 view). Đủ 1 plan. ✅
- **Nhất quán:** module (§3) ↔ luồng (§4) ↔ test (§5). ✅
- **Không placeholder mơ hồ:** 5 hàng disabled có lý do (chưa có backing), copy verbatim, primitive nhận tham số rõ. ✅
- **Rủi ro:** nền `dkWindowBg` trong detail có `.padding()` của `SettingsRootView` → có thể lộ viền nền mặc định quanh vùng ấm (chấp nhận; polish thống nhất nền sau khi cả 5 tab redesign); disabled Toggle vẫn cần binding → dùng `.constant(false)`.
