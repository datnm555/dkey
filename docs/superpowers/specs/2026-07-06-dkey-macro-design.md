# dkey Phase 4 — Feature "Gõ tắt" (Macro) Design Spec

**Ngày:** 2026-07-06
**Trạng thái:** Đã brainstorm & duyệt design — chờ user review spec trước khi viết plan.
**Phase trước:** Kiểu gõ, Giới thiệu, Chuyển mã — đã merge `main`.

Feature thứ 4 trong 5 sub-project hướng tới feature-parity với OpenKey
(Kiểu gõ ✅ → Giới thiệu ✅ → Chuyển mã ✅ → **Gõ tắt** → Hệ thống → Typing-extras).
Đây là sub-project **nặng nhất** vì phải tích hợp vào hot-path gõ.

---

## 1. Mục tiêu

Biến tab **"Gõ tắt"** thành công cụ macro: người dùng định nghĩa `từ tắt → nội dung`
(ví dụ `vn → Việt Nam`); khi gõ từ tắt rồi nhấn phím ngắt (space/dấu câu/enter), dkey
tự xóa từ tắt và chèn nội dung. Kèm dùng-trong-tiếng-Anh, tự-viết-hoa, và nhập/xuất.

### Phạm vi — TRONG
- Bảng macro `key → content` (Unicode). Khớp **từ đang hiển thị** khi gặp phím ngắt từ.
- Toggle **Bật gõ tắt** (`useMacro`), **Dùng cả trong tiếng Anh** (`useMacroInEnglishMode`),
  **Tự viết hoa theo từ gốc** (`autoCapsMacro`: `btw→by the way`, `Btw→By the way`, `BTW→BY THE WAY`).
- Persistence: file JSON `macros.json`; **Nhập/Xuất** = đọc/ghi file đó.
- Editor: bảng danh sách + ô Từ tắt/Nội dung + Thêm/Sửa/Xoá.

### Phạm vi — HOÃN / KHÔNG làm
- Token động (ngày/giờ), macro nhiều dòng có định dạng, hotkey riêng cho macro, per-app macro. Không làm.

### Success criteria
1. Định nghĩa `vn → Việt Nam`; gõ `vn ` → hiển thị `Việt Nam `. `Btw ` (auto-caps) → `By the way `.
2. Gõ tiếng Việt bình thường KHÔNG bị macro nuốt (từ không khớp → nguyên vẹn).
3. Macro chạy cả khi tắt tiếng Việt nếu bật `useMacroInEnglishMode`.
4. Thêm/Sửa/Xoá + Nhập/Xuất hoạt động; macro giữ qua các lần mở app.
5. `TelexEngine` không đổi; toàn bộ test hiện có (97) vẫn xanh.

---

## 2. Quyết định kiến trúc

- **Tách lõi thuần khỏi tích hợp**: `MacroTable` (tra cứu + auto-caps) là logic thuần, test được không cần AppKit/event-tap.
- **Macro sống ở lớp controller, KHÔNG trong engine**: `TelexEngine` giữ thuần Vietnamese. `MacroExpander` nằm trong
  `InputController` (lớp platform) — chạy **trên** quyết định VN on/off nên hoạt động cả ở chế độ tiếng Anh.
- **Khớp trên từ HIỂN THỊ** (post-transform), đúng OpenKey (`findMacro` gọi `getCharacterCode` trên chuỗi tích luỹ):
  `MacroExpander` theo dõi `currentWord` = chuỗi ký tự đang hiển thị, cập nhật từ mỗi `EngineOutput`/ký tự literal.
- **Persistence file-based**: macro list ↔ `macros.json`; import/export thao tác chính file này. 3 toggle → `DkeySettings`.

---

## 3. Thay đổi theo module

### 3.1 Lõi thuần
| File | Trách nhiệm |
|---|---|
| `Sources/Engine/Macro.swift` *(mới)* | `struct Macro: Codable, Equatable, Identifiable { var key: String; var content: String }`. |
| `Sources/Engine/MacroTable.swift` *(mới)* | Bọc `[String: String]` (key→content). `func expansion(for word: String, autoCaps: Bool) -> String?`: khớp key chính xác trước; nếu `autoCaps` & không khớp → hạ chữ thường key tra lại, áp hoa content theo pattern từ gõ (xem §4). Xây từ `[Macro]`. |

### 3.2 Tích hợp — `Sources/Platform/`
| File | Thay đổi |
|---|---|
| `MacroExpander.swift` *(mới)* | Giữ `currentWord: [Character]` + cấu hình (`enabled`, `englishMode`, `autoCaps`, `table`). API: `feed(output:vietnamese:) ` cập nhật currentWord; `onWordBreak(breakScalar:) -> [Unicode.Scalar]?` trả nội dung thay thế (đã gồm break) nếu khớp, kèm số backspace; `reset()`; `backspace()`. Thuần (không CGEvent). |
| `InputController.swift` *(sửa)* | Trong `handle`: sau khi có `EngineOutput`/passthrough, nếu là phím ngắt từ và macro bật (VN-on hoặc englishMode) → hỏi `MacroExpander`; nếu khớp → trả `.consume(backspaces:chars:)` (xóa từ tắt + gõ content + break). Ngược lại cập nhật `currentWord` như thường. Reset khi hotkey/otherControl. |

### 3.3 App
| File | Thay đổi |
|---|---|
| `MacroStore.swift` *(mới)* | Load/save `[Macro]` ↔ `~/Library/Application Support/dkey/macros.json` (tạo thư mục nếu chưa có). CRUD helpers. `importFrom(url:)` / `exportTo(url:)`. |
| `AppState.swift` *(sửa)* | `@Published var macros: [Macro]` + `useMacro`/`useMacroInEnglishMode`/`autoCapsMacro` (persist `DkeySettings`); didSet → cập nhật `controller`'s `MacroExpander` (table + flags). Load lúc init. |
| `DkeySettings.swift` *(sửa)* | Thêm `useMacro`, `useMacroInEnglishMode`, `autoCapsMacro` (Bool, default off). |
| `Views/MacroView.swift` *(mới)* | 3 toggle; `Table` macro; TextField Từ tắt + Nội dung + Thêm/Sửa/Xoá; nút Nhập/Xuất (`fileImporter`/`fileExporter`). |
| `Views/SettingsRootView.swift` *(sửa)* | `case .macro: MacroView()`. |

---

## 4. Ngữ nghĩa khớp & auto-caps

- **Ranh giới từ**: `currentWord` tích luỹ ký tự hiển thị từ sau phím ngắt gần nhất. Phím ngắt = space, enter, tab, dấu câu (`.,;:!?()"'…`). Backspace → pop.
- **Khi ngắt**: nếu macro bật & (VN-on hoặc englishMode), tra `currentWord`:
  - Khớp chính xác key → content.
  - `autoCaps` & không khớp chính xác → tra key hạ-thường; nếu thấy, áp hoa:
    - từ gõ toàn thường → content nguyên gốc;
    - ký tự đầu hoa & ký tự thứ 2 thường (hoặc từ 1 ký tự) → hoa ký tự đầu content;
    - ký tự đầu **và** thứ 2 đều hoa → HOA TOÀN BỘ content.
  (Bám `Macro.cpp:findMacro` + `modifyCaseUnicode`.)
- **Plan thay thế**: `backspaces = currentWord.count` (số ký tự hiển thị của từ tắt), `chars = content scalars + [break scalar]`. Reset `currentWord` sau đó.
- Không khớp → passthrough phím ngắt như hiện tại, reset `currentWord`.

---

## 5. Persistence

- `macros.json`: mảng `[{ "key": ..., "content": ... }]` tại `~/Library/Application Support/dkey/`.
- **Export**: copy/ghi `macros.json` ra url người dùng chọn. **Import**: đọc JSON (hoặc TSV `key<TAB>content` để tương thích OpenKey), merge/replace (mặc định merge; trùng key → ghi đè).
- Toggle macro trong `DkeySettings` (JSON UserDefaults sẵn có).

---

## 6. UI (tab Gõ tắt)

```
[x] Bật gõ tắt
    [ ] Dùng gõ tắt cả trong chế độ tiếng Anh
    [ ] Tự hoa theo từ gốc (btw→by the way, Btw→By the way)

┌───────────── Bảng macro ─────────────┐
│ Từ tắt        │ Nội dung             │
│ vn            │ Việt Nam             │
│ …             │ …                    │
└──────────────────────────────────────┘
[Từ tắt: ____]  [Nội dung: __________]  [Thêm/Sửa] [Xoá]
[Nhập…] [Xuất…]
```
Chọn dòng → nạp vào 2 ô để Sửa. Toggle con `.disabled(!useMacro)`.

---

## 7. Testing

### 7.1 Lõi thuần
- `MacroTableTests`: khớp chính xác; auto-caps `btw`/`Btw`/`BTW` → `by the way`/`By the way`/`BY THE WAY`; không khớp → nil; key/content Unicode (`vn→Việt Nam`).
- `MacroExpanderTests`: nạp chuỗi ký tự rồi break → trả đúng `(backspaces, chars)` gồm break + auto-caps; từ không khớp → nil (passthrough); backspace pop đúng; reset khi hotkey; English-mode (không cần engine).

### 7.2 Persistence
- `MacroStoreTests`: round-trip save/load; import JSON + import TSV; export tạo file đọc lại bằng; thư mục tự tạo; JSON hỏng → rỗng (không crash). Dùng thư mục tạm, không đụng Application Support thật.

### 7.3 Integration / non-regression
- `InputControllerMacroTests`: gõ `vn` + space với macro `vn→Việt Nam` → plan `consume(backspaces:2, chars:"Việt Nam ")`; gõ từ không phải macro → không đổi; macro off → không đổi; English mode + englishMode flag.
- Toàn bộ 97 test cũ xanh; gõ VN thường không bị macro can thiệp (curated).

---

## 8. YAGNI / ranh giới
- KHÔNG token động, per-app macro, hotkey macro, macro nhiều-bảng-mã. Mặc định 3 toggle off, `macros.json` rỗng.
- `TelexEngine` tuyệt đối không đổi (macro ở lớp controller).

---

## 9. Self-review
- **Phạm vi:** một feature (tab Gõ tắt) — lõi thuần + tích hợp controller + persistence + UI. Đủ cho 1 plan (chia task rõ). ✅
- **Nhất quán:** module (§3) ↔ ngữ nghĩa (§4) ↔ test (§7); `MacroTable`/`MacroExpander`/`MacroStore` ranh giới rõ. ✅
- **Không placeholder:** auto-caps rule, break set, plan cụ thể; nguồn tham chiếu (`Macro.cpp:findMacro`) rõ. ✅
- **Không mơ hồ:** macro ở controller (không engine); khớp trên từ hiển thị; ranh giới HOÃN rõ. ✅
- **Rủi ro:** tích hợp `InputController` là điểm dễ lệch — phủ bằng `InputControllerMacroTests` + smoke; engine giữ nguyên nên parity Telex/VNI không đổi.
