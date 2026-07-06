# dkey Phase 3c — Feature "Chuyển mã" (Convert tool) Design Spec

**Ngày:** 2026-07-06
**Trạng thái:** Đã brainstorm & duyệt design — chờ user review spec trước khi viết plan.
**Phase trước:** Kiểu gõ (Telex+VNI) và Giới thiệu (About) — đã merge `main`.

Feature thứ 3 trong 5 sub-project hướng tới feature-parity với OpenKey
(Kiểu gõ ✅ → Giới thiệu ✅ → **Chuyển mã** → Gõ tắt → Hệ thống → Typing-extras).

---

## 1. Mục tiêu

Biến tab **"Chuyển mã"** thành công cụ **convert một đoạn văn bản giữa các bảng mã tiếng Việt**
(Unicode ⇄ TCVN3 ⇄ VNI-Windows ⇄ Unicode tổ hợp ⇄ CP1258), kèm đổi hoa/thường và bỏ dấu.
Đây đúng là cái OpenKey gọi là "Chuyển mã" (`ConvertTool`) — **hoạt động độc lập với engine gõ live**.

### Phạm vi — TRONG
- 5 bảng mã: `0 Unicode`, `1 TCVN3 (ABC)`, `2 VNI Windows`, `3 Unicode tổ hợp`, `4 CP1258`.
- Convert 1 đoạn text từ bảng nguồn → bảng đích (port faithful `ConvertTool.cpp`).
- 5 kiểu chữ: Giữ nguyên / IN HOA / in thường / Hoa đầu câu / Hoa Mỗi Từ.
- Toggle "Loại bỏ dấu thanh" (tiếng Việt → khong dau).
- UI: nhập text trong app → ô kết quả cập nhật **live** → nút Copy. Lưu lựa chọn bằng `@AppStorage`.

### Phạm vi — HOÃN / KHÔNG làm
- **Live output encoding** (`vCodeTable` — gõ trực tiếp ra TCVN3/VNI-Win): đổi representation output
  của engine (hiện `[Unicode.Scalar]`; legacy table là byte đóng gói) → to & rủi ro, giá trị thấp năm 2026. Hoãn.
- Convert kiểu clipboard + hotkey (OpenKey): dùng ô text trong app thay thế, không cần system integration.

### Success criteria
1. Nhập text Việt (Unicode) → chọn Sang bảng mã TCVN3/VNI-Win/… → ô kết quả đúng byte-for-byte với OpenKey.
2. Round-trip: Unicode → X → Unicode trả về chuỗi gốc (với X ∈ mọi bảng).
3. Kiểu chữ + bỏ dấu hoạt động đúng; ký tự không phải tiếng Việt giữ nguyên.
4. Không đụng engine gõ; toàn bộ test hiện có (83) vẫn xanh. Engine vẫn pure-Swift.

---

## 2. Quyết định kiến trúc

- **Tách core thuần khỏi UI**: `ConvertTool.convert(...)` là hàm thuần trên `String` → test được không cần AppKit.
- **Faithful port + oracle parity**: port `ConvertTool.cpp` + `_codeTable[1..4]` sang Swift; đúng phương pháp
  đã dùng cho engine — **oracle định nghĩa đáp án**, sinh corpus golden, parity-test. Bảng mã là dữ liệu nhạy
  cảm (byte đóng gói) nên oracle là cách an toàn nhất để khớp OpenKey.
- **Persistence tách biệt**: lựa chọn convert (from/to/case/removeMark) lưu bằng `@AppStorage` (Int/Bool),
  KHÔNG nhét vào `DkeySettings` (đó là model của engine typing). Cô lập, không đụng engine settings.
- **Không đụng hot-path**: convert thao tác trên text đã có, không nằm trong đường gõ phím → 0 rủi ro hồi quy engine.

---

## 3. Thay đổi theo module

### 3.1 `Sources/Engine/` (pure Swift)
| File | Trách nhiệm |
|---|---|
| `CodeTable.swift` *(mới)* | `enum CodeTable: Int, CaseIterable { case unicode=0, tcvn3, vniWindows, unicodeCompound, cp1258 }` + `displayName`. Dữ liệu bảng: `codeTables: [Int: [UInt32: [UInt16]]]` port `_codeTable[1..4]` (bảng [0] = `codeTableUnicode` sẵn có) + `unicodeCompoundMark: [UInt16]` (5 dấu tổ hợp). |
| `ConvertTool.swift` *(mới)* | `enum CaseMode: Int { case keep=0, upper, lower, sentence, title }`; `func convert(_ text: String, from: CodeTable, to: CodeTable, caseMode: CaseMode, removeMark: Bool) -> String`. Port faithful `../mkey/Sources/Engine/ConvertTool.cpp` (`findKeyCode` reverse-lookup theo bảng nguồn → map sang bảng đích → giải mã giá trị đóng gói theo từng loại table; xử lý caps k±1; `_breakCode` cho "Hoa đầu câu"; remove-mark). |

### 3.2 `Sources/App/`
| File | Thay đổi |
|---|---|
| `Views/ConvertView.swift` *(mới)* | Picker Từ/Sang bảng mã + nút swap; Picker Kiểu chữ (5); Toggle Loại bỏ dấu; `TextEditor` input; ô kết quả read-only tính **reactive** = `ConvertTool.convert(input, from, to, case, removeMark)`; nút "Copy kết quả" (`NSPasteboard`). State qua `@AppStorage("convert.from"/"convert.to"/"convert.case"/"convert.removeMark")`. |
| `Views/SettingsRootView.swift` *(sửa)* | Thêm `case .convert: ConvertView()` vào switch (hiện route `.typing`/`.about`, còn lại placeholder). |

---

## 4. Thuật toán convert (port `ConvertTool.cpp`)

Với mỗi ký tự nguồn:
1. `findKeyCode(char, fromTable) -> (j, k)`: tìm ký tự trong `codeTables[fromTable]` — `j` = entry (nhóm nguyên âm/keycode), `k` = vị trí (gồm caps + mark index). Bảng nguồn dạng byte đóng gói (2 byte) cần ghép trước khi so.
2. Nếu tìm thấy: `target = codeTables[toTable][j][k]` (điều chỉnh k±1 cho biến thể hoa/thường như C++).
3. Giải mã `target` theo **loại bảng đích**: Unicode → 1 scalar; TCVN3 → 1 byte; VNI-Win/CP1258 → tách 1–2 byte; Unicode tổ hợp → base + `unicodeCompoundMark[markIdx]`. (Theo nhánh output trong `ConvertTool.cpp`.)
4. Nếu không phải ký tự tiếng Việt trong bảng nguồn → giữ nguyên.
Sau khi map: áp `caseMode` (dùng `_breakCode = . ? !` cho "Hoa đầu câu") và `removeMark` (map về nguyên âm trần).

Chi tiết byte/nhánh **bám sát `ConvertTool.cpp`**; corpus oracle là lưới an toàn (không tự bịa đáp án).

---

## 5. Testing

### 5.1 Oracle-backed parity
- Mở rộng `scripts/openkey-oracle` (hoặc oracle chị em) thêm chế độ **convert**: nhận `(text, fromCode, toCode)` → gọi
  `ConvertTool` thật của OpenKey → in kết quả. Build offline.
- `scripts/gen-convert-corpus.sh` *(mới)* sinh `Tests/Fixtures/convert-corpus.json` (committed): mỗi dòng
  `{text, from, to, expected}` cho các cặp bảng (đặc biệt Unicode↔{TCVN3,VNI-Win,Compound,CP1258}) trên wordlist Việt.
- `Tests/ConvertTests/ConvertParityTests.swift` *(mới)*: nạp corpus, gọi `ConvertTool.convert`, assert khớp golden.

### 5.2 Curated (`Tests/ConvertTests/ConvertToolTests.swift` — mới)
- Round-trip: `convert(convert(s, .unicode, X), X, .unicode) == s` cho X ∈ {tcvn3, vniWindows, unicodeCompound, cp1258}.
- Case modes: "tiếng việt" → IN HOA / in thường / Hoa đầu câu / Hoa Mỗi Từ đúng.
- removeMark: "tiếng Việt" → "tieng Viet".
- Non-Việt giữ nguyên: "abc 123 @#" không đổi (Unicode→Unicode và cross-table).
- Unicode tổ hợp: 1 âm tiết → base + combining mark đúng thứ tự.

### 5.3 Không hồi quy
Toàn bộ 83 test hiện có + build engine pure-Swift phải xanh. `xcodegen generate` sau khi thêm file mới.

---

## 6. YAGNI / ranh giới
- KHÔNG live-encoding (`vCodeTable`), KHÔNG clipboard-hotkey, KHÔNG convert file, KHÔNG persistence trong `DkeySettings`.
- Mặc định: Từ = Unicode, Sang = TCVN3, Kiểu chữ = Giữ nguyên, removeMark = off.

---

## 7. Self-review
- **Phạm vi:** đủ cho 1 plan (data tables + 1 hàm convert thuần + 1 view + test). ✅
- **Nhất quán:** module (mục 3) ↔ thuật toán (4) ↔ test (5); enum `CodeTable`/`CaseMode` dùng nhất quán. ✅
- **Không placeholder:** chỉ số bảng mã, danh sách case mode, nguồn dữ liệu (`ConvertTool.cpp`, `_codeTable[1..4]`) đều cụ thể. ✅
- **Không mơ hồ:** ranh giới HOÃN (live-encoding) rõ; oracle là nguồn chân lý cho byte đóng gói. ✅
