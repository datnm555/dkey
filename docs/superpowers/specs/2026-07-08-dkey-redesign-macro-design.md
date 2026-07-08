# dkey Redesign — Screen ④ Gõ tắt (macro tab) Design Spec

**Ngày:** 2026-07-08
**Trạng thái:** Đã brainstorm & duyệt design — chờ user review spec trước khi viết plan.
**Bối cảnh:** Redesign UI 6 màn theo `DKey Mockups.standalone.html`, tuần tự per-screen. ①②③ đã xong + merge `main`. Đây là **sub-project 4/6: restyle tab Gõ tắt** (macro) theo mockup screen 1c.

---

## 1. Mục tiêu

Tab Gõ tắt (`MacroView`) **đã đủ chức năng** (bảng macro, thêm/sửa/xoá, 3 toggle chế độ, Nhập/Xuất). Sub-project này **restyle** sang phong cách card theo mockup (dùng lại `SectionCard`/`ToggleRow` từ ③) và **thêm ô tìm kiếm** lọc danh sách. Không đụng engine, không đổi model. Không hoãn feature nào.

### Phạm vi — TRONG
- **`MacroFilter`** (logic thuần, test được): `static func filter(_ macros: [Macro], query: String) -> [Macro]` — trim query; rỗng → trả tất cả; ngược lại lọc **case-insensitive substring** trên `key` HOẶC `content`.
- **`MacroView`** viết lại theo Theme card:
  - **Card "Tùy chọn gõ tắt"**: 3 toggle hiện có, render bằng `ToggleRow` tái dùng (kiểm chứng primitive trên toggle **thật, enabled**):
    - "Bật gõ tắt" → `$state.useMacro` (luôn enabled).
    - "Dùng gõ tắt cả trong chế độ tiếng Anh" → `$state.useMacroInEnglishMode`, `enabled: state.useMacro`.
    - "Tự hoa theo từ gốc" (subtitle "btw→by the way, Btw→By the way") → `$state.autoCapsMacro`, `enabled: state.useMacro`.
  - **Card "Gõ tắt"** (quản lý danh sách):
    - Toolbar: ô tìm kiếm (`TextField` + icon ⌕, placeholder "Tìm gõ tắt…") + Spacer + **Nhập…** / **Xuất…**.
    - `Table` cột **"Gõ tắt" | "Thay thế bằng"**, hiển thị `MacroFilter.filter(state.macros, query:)`.
    - Hàng thêm/sửa: `TextField` "Từ tắt" + `TextField` "Nội dung thay thế" + nút **Thêm/Sửa** + **Xoá**.
  - Nền `Color.dkWindowBg`.
- Giữ nguyên toàn bộ hành vi: thêm/sửa/xoá thao tác trên `state.macros` đầy đủ (không phải danh sách đã lọc); chọn 1 hàng (kể cả khi đang lọc) nạp vào editor như hiện tại; `.fileImporter`/`.fileExporter` giữ nguyên logic merge/ghi.

### Phạm vi — HOÃN
Không có feature engine để hoãn. Không đụng các tab khác, không đụng `MacroStore`/`MacroExpander`/engine.

### Success criteria
1. Tab Gõ tắt hiển thị 2 card style mockup (nền/panel/màu theo Theme).
2. 3 toggle vẫn hoạt động; 2 toggle con mờ + inert khi "Bật gõ tắt" tắt.
3. Gõ vào ô tìm kiếm → bảng chỉ còn macro khớp (key hoặc content, không phân biệt hoa/thường); xoá query → hiện lại tất cả.
4. Thêm/Sửa/Xoá và Nhập/Xuất vẫn hoạt động đúng (trên toàn bộ `state.macros`, kể cả khi đang lọc).
5. Không đụng engine; `DkeySettings`/`AppState`/`MacroStore` model không đổi; test cũ (143) vẫn xanh + test mới `MacroFilter`.

---

## 2. Quyết định kiến trúc

- **Tách logic lọc thuần khỏi view**: `MacroFilter.filter` là hàm thuần, test được (empty/trim/case-insensitive/khớp key vs content); view chỉ render kết quả.
- **Dùng lại `ToggleRow`/`SectionCard` (③)** cho toggle thật — không viết lại; kiểm chứng primitive hoạt động cho toggle enabled (không chỉ placeholder). Không tạo component mới (YAGNI) — ô tìm kiếm inline trong `MacroView` (chỉ ④ cần).
- **Lọc chỉ ảnh hưởng hiển thị**: mọi thao tác ghi (thêm/sửa/xoá/nhập) vẫn trên `state.macros` gốc → tránh mất dữ liệu khi đang lọc. Selection dùng `Macro.ID` (== key) nên vẫn khớp giữa danh sách lọc và editor.
- **Không đụng engine/model.** `MacroFilter` đặt ở `Sources/App` (mối quan tâm UI-tab), tham chiếu `Macro` (Engine, cùng target).

---

## 3. Thay đổi theo module (`Sources/App/`)

| File | Trách nhiệm |
|---|---|
| `MacroFilter.swift` *(mới)* | `enum MacroFilter { static func filter(_ macros: [Macro], query: String) -> [Macro] }`. Trim; rỗng→all; case-insensitive contains trên key OR content. |
| `Views/MacroView.swift` *(viết lại)* | `ScrollView`/`VStack` 2 `SectionCard`; toggle bằng `ToggleRow`; toolbar tìm kiếm + Nhập/Xuất; `Table` (Gõ tắt/Thay thế bằng) trên danh sách đã lọc; hàng thêm/sửa/xoá; giữ `@State searchQuery`, `selection`, `keyField`, `contentField`, `importing`, `exporting`; giữ `MacrosDocument`, `.fileImporter`/`.fileExporter`, `addOrEdit`/`deleteSelected`/`existsKey`. |

Không đổi `Macro.swift`, `MacroStore.swift`, `AppState.swift`, `SettingsComponents.swift`, `Theme.swift`, engine.

---

## 4. Luồng

```
SettingsRootView → detail → MacroView
MacroView (@State searchQuery=""):
  SectionCard("Tùy chọn gõ tắt") {
    ToggleRow("Bật gõ tắt", isOn: $state.useMacro)
    ToggleRow("Dùng gõ tắt cả trong chế độ tiếng Anh", isOn: $state.useMacroInEnglishMode, enabled: state.useMacro)
    ToggleRow("Tự hoa theo từ gốc", subtitle:"btw→by the way, Btw→By the way", isOn:$state.autoCapsMacro, enabled: state.useMacro)
  }
  SectionCard("Gõ tắt") {
    HStack { [⌕ TextField "Tìm gõ tắt…" bind $searchQuery]  Spacer  Button "Nhập…"  Button "Xuất…" }
    Table(MacroFilter.filter(state.macros, query: searchQuery), selection: $selection) {
      TableColumn("Gõ tắt", value: \.key); TableColumn("Thay thế bằng", value: \.content)
    }
    HStack { TextField "Từ tắt" $keyField; TextField "Nội dung thay thế" $contentField;
             Button(existsKey ? "Sửa":"Thêm"){addOrEdit()}; Button("Xoá",destructive){deleteSelected()} }
  }
  .fileImporter/.fileExporter (giữ nguyên)
```
- `onChange(of: selection)`: chọn → nạp key/content vào editor; bỏ chọn → xoá field (như hiện tại).
- Thêm/sửa/xoá/nhập: thao tác trên `state.macros` (không phải danh sách lọc).

---

## 5. Testing
- `MacroFilterTests`:
  - query rỗng (và toàn khoảng trắng) → trả nguyên danh sách.
  - khớp theo `key` (case-insensitive): `filter([vn→Việt Nam, kg→Kính gửi], "VN")` → chỉ `vn`.
  - khớp theo `content` (case-insensitive): query "gửi" → chỉ `kg`.
  - không khớp → mảng rỗng.
  - giữ thứ tự tương đối của danh sách gốc.
- `MacroView` + restyle: BUILD SUCCEEDED + smoke thủ công (deferred user: 2 card; 3 toggle chạy + 2 toggle con mờ khi tắt; gõ tìm kiếm lọc bảng; thêm/sửa/xoá/nhập/xuất chạy).
- Không hồi quy engine (143 test cũ vẫn xanh).

## 6. YAGNI
Chỉ 1 helper lọc thuần + viết lại 1 view (dùng lại primitive ③). Không component mới, không đổi model, không đụng tab/engine khác.

## 7. Self-review
- **Phạm vi:** 1 sub-project nhỏ (1 helper + rewrite 1 view). Đủ 1 plan. ✅
- **Nhất quán:** module (§3) ↔ luồng (§4) ↔ test (§5). ✅
- **Không placeholder mơ hồ:** lọc case-insensitive key/content cụ thể; copy verbatim; giữ đúng hành vi ghi trên danh sách gốc. ✅
- **Rủi ro:** lọc khi đang có selection → nếu hàng đang chọn bị lọc khỏi bảng, editor vẫn giữ field (chấp nhận; thao tác vẫn trên state.macros gốc); `Table` selection type `Macro.ID` (String) khớp cả khi lọc.
