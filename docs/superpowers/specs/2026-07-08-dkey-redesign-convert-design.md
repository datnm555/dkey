# dkey Redesign — Screen ⑤ Chuyển mã (convert tab) Design Spec

**Ngày:** 2026-07-08
**Trạng thái:** Đã brainstorm & duyệt design — chờ user review spec trước khi viết plan.
**Bối cảnh:** Redesign UI 6 màn theo `DKey Mockups.standalone.html`, tuần tự per-screen. ①②③④ đã xong + merge `main`. Đây là **sub-project 5/6: restyle tab Chuyển mã** theo mockup convert screen.

---

## 1. Mục tiêu

Tab Chuyển mã (`ConvertView`) **đã đủ chức năng** (chọn bảng mã Từ/Sang + hoán đổi, Kiểu chữ, Loại bỏ dấu thanh, ô nguồn/kết quả, copy; convert **live** qua `ConvertTool`). Sub-project này **restyle** sang phong cách card theo mockup (dùng lại `SectionCard`/`ToggleRow`). Không đụng engine (`ConvertTool`/`CodeTable`/`CaseMode` đã có + đã test qua convert corpus), không đổi model, không thêm logic. **Không hoãn feature nào.**

### Phạm vi — TRONG
- **`ConvertView`** viết lại theo Theme card, giữ nguyên `@AppStorage` keys + gọi `ConvertTool.convert` + convert **live** (computed `output`):
  - **Card "Bảng mã"**: `Picker` **Từ bảng mã** (`CodeTable.allCases`, bind `convert.from`), nút hoán đổi (`arrow.left.arrow.right`), `Picker` **Sang bảng mã** (bind `convert.to`); dưới là `Picker` **Kiểu chữ** (`CaseMode.allCases`, bind `convert.case`) và **Loại bỏ dấu thanh** qua `ToggleRow` (bind `convert.removeMark`).
  - **Card "Văn bản nguồn"**: `TextEditor` bind `$input`.
  - **Card "Kết quả"**: `TextEditor(text: .constant(output))` (read-only) + nút **Sao chép kết quả** (`NSPasteboard`).
  - Nền `Color.dkWindowBg`.
- Giữ **convert live** (kết quả tự cập nhật khi gõ/đổi bảng mã) — không thêm nút "Chuyển mã" thủ công.

### Phạm vi — HOÃN
Không có feature engine để hoãn. "Chuyển nhanh clipboard" và "Ghi nhớ bảng mã theo app" thuộc **màn ⑥ Hệ thống**, không phải ⑤. Không đụng tab/engine khác.

### Success criteria
1. Tab Chuyển mã hiển thị 3 card style mockup (nền/panel/màu theo Theme).
2. Chọn Từ/Sang bảng mã + nút hoán đổi vẫn hoạt động; Kiểu chữ + Loại bỏ dấu thanh vẫn hoạt động.
3. Gõ vào ô nguồn → ô kết quả tự cập nhật (live) qua `ConvertTool`; "Sao chép kết quả" copy đúng.
4. `@AppStorage` keys (`convert.from/to/case/removeMark`) giữ nguyên → cấu hình cũ tương thích.
5. Không đụng engine; test cũ (149) vẫn xanh (không thêm logic mới nên không test mới).

---

## 2. Quyết định kiến trúc

- **Pure view restyle**: không thêm logic → không helper thuần mới, không test mới. `ConvertTool.convert(...)` đã có + đã test qua convert corpus; view chỉ đổi trình bày. → **1 task duy nhất** (rewrite view, build-verified).
- **Dùng lại `SectionCard`/`ToggleRow` (③)**; không component mới (YAGNI).
- **Giữ live conversion** (computed `output`) — UX tốt hơn nút thủ công, đã chạy; không regression.
- **Giữ nguyên `@AppStorage` keys** → không mất cấu hình người dùng.
- **Không đụng engine/model.**

---

## 3. Thay đổi theo module (`Sources/App/`)

| File | Trách nhiệm |
|---|---|
| `Views/ConvertView.swift` *(viết lại)* | `ScrollView`/`VStack` 3 `SectionCard`; giữ `@AppStorage convert.from/to/case/removeMark`, `@State input`, computed `output = ConvertTool.convert(...)`; pickers Từ/Sang + swap + Kiểu chữ + `ToggleRow` Loại bỏ dấu; TextEditor nguồn; TextEditor kết quả read-only + nút Sao chép. Nền `dkWindowBg`. |

Không đổi `ConvertTool.swift`, `CodeTable.swift`, `AppState.swift`, `SettingsComponents.swift`, `Theme.swift`, `SettingsRootView.swift`, engine.

---

## 4. Luồng

```
SettingsRootView → detail → ConvertView
ConvertView (@AppStorage convert.*, @State input):
  output = ConvertTool.convert(input, from: CodeTable(from), to: CodeTable(to), caseMode: CaseMode(case), removeMark:)
  SectionCard("Bảng mã") {
    HStack { Picker "Từ bảng mã" ($fromRaw, CodeTable.allCases)
             Button(swap: from↔to) [arrow.left.arrow.right]
             Picker "Sang bảng mã" ($toRaw, CodeTable.allCases) }
    Picker "Kiểu chữ" ($caseRaw, CaseMode.allCases)
    ToggleRow "Loại bỏ dấu thanh (tiếng Việt → khong dau)" isOn:$removeMark
  }
  SectionCard("Văn bản nguồn") { TextEditor($input) }
  SectionCard("Kết quả") { TextEditor(.constant(output)) read-only
                           Button "Sao chép kết quả" → NSPasteboard }
  .background(dkWindowBg)
```

---

## 5. Testing
- Không có logic mới → **không test unit mới**. `ConvertTool` đã có convert corpus + test (không đụng).
- `ConvertView` restyle: BUILD SUCCEEDED + smoke thủ công (deferred user: 3 card; chọn Từ/Sang + hoán đổi; Kiểu chữ + Loại bỏ dấu; gõ nguồn → kết quả live; Sao chép).
- Không hồi quy: 149 test cũ vẫn xanh.

## 6. YAGNI
Chỉ viết lại 1 view (dùng lại primitive ③). Không logic mới, không component mới, không đổi model/engine, không nút convert thủ công.

## 7. Self-review
- **Phạm vi:** 1 sub-project rất nhỏ (rewrite 1 view). Đủ 1 plan (1 task). ✅
- **Nhất quán:** module (§3) ↔ luồng (§4) ↔ test (§5). ✅
- **Không placeholder mơ hồ:** giữ AppStorage keys + ConvertTool call cụ thể; copy verbatim; live conversion rõ. ✅
- **Rủi ro:** `TextEditor` trong `SectionCard`/`ScrollView` (không phải Form) cần `minHeight` cố định để hiển thị; nút Sao chép dùng `NSPasteboard` (giữ như hiện tại). Không rủi ro engine.
