# dkey Phase 3a — Feature "Kiểu gõ" (Telex + VNI) Design Spec

**Ngày:** 2026-07-03
**Trạng thái:** Đã brainstorm — chờ user duyệt spec trước khi viết implementation plan.
**Phase trước:** Phase 0 (scaffold), Phase 1 (Telex engine), Phase 2 (platform event-tap) — đã merge `main`.

Đây là feature **đầu tiên** trong 4 feature còn lại (Kiểu gõ → Giới thiệu → Chuyển mã → Gõ tắt),
làm **tuần tự**, mỗi feature một spec + plan riêng. Feature này cũng dựng **lớp lưu settings chung**
mà 3 feature sau tái sử dụng.

---

## 1. Mục tiêu

Biến tab **"Kiểu gõ"** từ placeholder thành chức năng thật, và mở rộng engine để hỗ trợ **VNI** bên
cạnh Telex. Người dùng chọn kiểu gõ, kiểu bỏ dấu (mới/cũ), và tự đặt phím chuyển ngôn ngữ; mọi lựa
chọn **được lưu lại** giữa các lần mở app.

### Phạm vi — TRONG feature này
- **Engine VNI:** port faithful nhánh VNI của OpenKey (`vInputType==1`). Phím số đặt dấu:
  `1..5` = sắc/huyền/hỏi/ngã/nặng, `6` = mũ (â/ê/ô), `7` = móc (ơ/ư), `8` = ă (breve), `9` = đ,
  `0` = xóa dấu. Output vẫn **Unicode NFC** (dùng lại `codeTableUnicode` sẵn có).
- **Chọn kiểu gõ** Telex ↔ VNI, áp dụng live cho engine.
- **Kiểu bỏ dấu** mới (`hoà`, `uý`) ↔ cũ (`hòa`, `úy`) — expose cờ `useModernOrthography` đã có.
- **Phím chuyển ngôn ngữ:** ô "thu phím tự do" (KeyRecorder) bắt tổ hợp bất kỳ (ví dụ ⌥Z, ⌃⇧),
  encode về bitfield `switchKeyStatus` hiện có; `HotkeyMatcher` không đổi.
- **Lớp lưu settings chung** (`Codable` + `UserDefaults`): lưu kiểu gõ, kiểu bỏ dấu, phím chuyển,
  và trạng thái Tiếng Việt bật/tắt. Load lúc khởi động, lưu khi thay đổi.

### Phạm vi — HOÃN (feature/phase sau)
- Bảng mã output khi gõ (Unicode/TCVN3/VNI-Windows/VIQR/VPS) + tool convert → **tab Chuyển mã**.
- Macro/gõ tắt → **tab Gõ tắt**.
- Simple Telex 1/2, VIQR; auto-caps; spell-check/restore-if-wrong; free-mark; quick-telex;
  per-app override; login item (SMAppService). Không nằm trong feature này.

### Success criteria
1. Chọn **VNI** trong Settings → gõ `a1→á`, `a6→â`, `o7→ơ`, `u7→ư`, `a8→ă`, `d9→đ`,
   `a1` rồi `0`→`a`, cụm `viet65` kiểu → `việt`… đúng (curated tests xanh).
2. **VNI parity corpus** sinh từ OpenKey oracle (`vInputType=1`) khớp golden trên toàn corpus.
3. **Không hồi quy Telex:** toàn bộ parity corpus Telex hiện tại + 58 test cũ vẫn xanh.
4. Đổi kiểu gõ / kiểu bỏ dấu / phím chuyển trong UI → có hiệu lực **ngay** và **được lưu**,
   mở lại app vẫn giữ.
5. Build sạch target `dkey`; engine vẫn pure-Swift, không kéo AppKit vào `Sources/Engine`.

---

## 2. Quyết định kiến trúc

### 2.1 Thêm VNI — Hướng A: tách "Input-Method strategy" trong engine
Lõi đặt dấu (`insertMark`, `insertAOE`, `insertW`, `insertD`, `removeMark`, `findAndCalculateVowel`,
`checkGrammar`, `getCharacterCode`) **độc lập kiểu gõ**. Phần khác nhau giữa Telex và VNI chỉ là
**"phím nào → ý định gì"** ở đầu `handle`.

→ Giới thiệu khái niệm **KeyIntent** + **InputMethod**:
- `enum InputMethod { case telex, vni }` (thuộc engine, pure Swift).
- `handle` phân loại phím theo `inputMethod` thành một *ý định* rồi dispatch tới đúng hàm lõi.
- Nhánh **Telex giữ nguyên hành vi** (parity corpus Telex là lưới an toàn cho refactor).
- Nhánh **VNI** port faithful từ OpenKey `vKeyHandleEvent` khi `vInputType==1`.

Đúng mô hình OpenKey (một engine, switch theo `vInputType`) → giữ được phương pháp parity.
Loại hướng "dịch VNI→Telex trước khi vào engine" (mong manh, ngữ nghĩa `6/7/8` khác `aa/w`)
và hướng "engine VNI riêng" (trùng lặp dispatch, dễ lệch khi sửa lõi).

### 2.2 Persistence — `Codable` snapshot trên `UserDefaults`
Hiện **chưa có** persistence nào (không `UserDefaults`/`@AppStorage`). Dựng một `SettingsStore` nhỏ:
model `DkeySettings: Codable`, serialize JSON vào một key `UserDefaults`. `AppState` là nguồn sự thật
cho UI; mỗi property lưu-được khi `didSet` sẽ (a) áp vào `controller`/`engine`, (b) ghi snapshot.
Đơn giản, không thêm dependency, test round-trip dễ.

---

## 3. Thay đổi theo module

### 3.1 `Sources/Engine/` (pure Swift)
| File | Thay đổi |
|---|---|
| `InputMethod.swift` *(mới)* | `enum InputMethod { case telex, vni }`. Có thể chứa bảng map phím VNI→intent (hằng số thuần). |
| `EngineOutput.swift` | Thêm `var inputMethod: InputMethod { get set }` vào `protocol InputEngine`. |
| `TelexEngine.swift` | Thêm `public var inputMethod: InputMethod = .telex`. Ở đầu `handle`, khi `.vni` đi nhánh phân loại phím VNI; khi `.telex` giữ nguyên chuỗi nhánh hiện tại. Nếu file phình, tách `TelexEngine+VNI.swift` (quyết định ở bước plan). |

**Giữ tên `TelexEngine`** để không vỡ API/test hiện có; nó trở thành "Vietnamese engine đa kiểu gõ,
mặc định Telex". (Đổi tên rộng để dành refactor riêng, không gộp vào feature này.)

#### Ánh xạ phím VNI → ý định (port từ OpenKey, `vInputType==1`)
| Phím VNI | Ý định | Hàm lõi tái sử dụng |
|---|---|---|
| `1 2 3 4 5` | sắc / huyền / hỏi / ngã / nặng | `insertMark(mark1..5)` |
| `6` | mũ (â/ê/ô) áp lên **nguyên âm hiện tại** | `insertAOE(...)` với target suy từ buffer (không từ phím) |
| `7` | móc (ơ/ư) | nhánh horn của `insertW` |
| `8` | ă (breve) | nhánh breve của `insertW` |
| `9` | đ | `insertD` |
| `0` | xóa dấu (như `z` của Telex) | `removeMark` |
| phím khác | ký tự thô | `insertKey` |

Khác biệt cốt lõi so với Telex: `6/7/8` của VNI áp diacritic lên **nguyên âm đang có** (không phải
"gõ đôi" như `aa`, không phải phím `w`). Cần đối chiếu đúng cách OpenKey chọn nguyên âm nhận
mũ/móc/ă trong nhánh VNI, kể cả toggle-off (gõ lại phím số dấu để huỷ) và fallthrough khi không có
nguyên âm hợp lệ (phím số trở thành ký tự thô).

### 3.2 `Sources/App/`
| File | Thay đổi |
|---|---|
| `DkeySettings.swift` *(mới)* | `struct DkeySettings: Codable, Equatable { var inputMethod; var useModernOrthography; var switchKeyStatus; var isVietnamese }` + `static let defaults`. |
| `SettingsStore.swift` *(mới)* | `load() -> DkeySettings` / `save(_:)` qua `UserDefaults` (JSON). Một key, ví dụ `"dkey.settings.v1"`. |
| `AppState.swift` | Thêm `@Published var inputMethod: InputMethod`. `didSet` của `inputMethod`, `useModernOrthography` (thêm mới nếu chưa), `switchKeyStatus`, `isVietnamese` → áp vào `controller`/`engine` + `store.save(snapshot)`. `init` gọi `store.load()` và áp toàn bộ trước khi tap chạy. |
| `Views/SettingsRootView.swift` | Nhánh `.typing` render `TypingSettingsView()` thay cho placeholder. Các tab khác vẫn placeholder. |
| `Views/TypingSettingsView.swift` *(mới)* | Picker Kiểu gõ (Telex/VNI), Picker/Toggle Kiểu bỏ dấu (mới/cũ), ô KeyRecorder cho phím chuyển. |
| `KeyRecorderField.swift` *(mới)* | View bắt keyDown tiếp theo (kèm modifier) → encode bitfield → cập nhật `state.switchKeyStatus`. |

### 3.3 `Sources/Platform/`
| File | Thay đổi |
|---|---|
| `InputController.swift` | `setVietnamese` đã có; thêm setter đồng bộ `switchKeyStatus` và forward `inputMethod`/`useModernOrthography` xuống `engine` (hoặc `AppState` set thẳng `controller.engine.inputMethod`). Không đổi luồng `handle`. |

`HotkeyMatcher` **không đổi** — bitfield format giữ nguyên.

---

## 4. Thiết kế UI — tab "Kiểu gõ"

Layout `Form` dọc, style Settings chuẩn macOS:

```
Kiểu gõ:           ( ) Telex     ( ) VNI            ← Picker .segmented / radio
Kiểu bỏ dấu:       ( ) Mới  (hoà, uý)               ← 2 lựa chọn, map useModernOrthography
                   ( ) Cũ   (hòa, úy)                  (mới = true)
Phím chuyển:       [  ⌥Z  ]  (bấm để ghi)            ← KeyRecorderField
                   Gợi ý: cần ít nhất 1 phím bổ trợ.
```

- Đổi bất kỳ control nào → cập nhật `AppState` ngay (didSet lo áp engine + lưu).
- Không có nút "Lưu"/"Áp dụng" — thay đổi có hiệu lực tức thì (chuẩn Settings macOS).

---

## 5. Thiết kế KeyRecorder + bitfield

Bitfield `switchKeyStatus` hiện dùng (khớp `HotkeyMatcher` + `AppState.hotkeyDescription`):
- **byte thấp `& 0xFF`** = keyCode (macOS virtual key), ví dụ `0x06` = phím Z.
- **`0x100/0x200/0x400/0x800`** = ⌃ Control / ⌥ Option / ⌘ Command / ⇧ Shift.
- **byte cao `>>24`** = ASCII ký tự hiển thị, ví dụ `0x7A` = `z`. (Mặc định ⌥Z = `0x7A000206`.)

KeyRecorder:
1. Vào chế độ ghi (focus / click), bắt **keyDown kế tiếp**: lấy `keyCode`, `modifierFlags`, và ký tự
   hiển thị (từ charactersIgnoringModifiers hoặc map keyCode→ASCII).
2. Encode: `status = (displayASCII<<24) | modBits | keyCode`.
3. **Validate:** yêu cầu ≥ 1 phím bổ trợ (tránh bắt 1 chữ cái trần làm phím chuyển). Nếu không hợp
   lệ → không nhận, hiển thị gợi ý.
4. Cập nhật `state.switchKeyStatus` (didSet → `controller.switchKeyStatus` + lưu).

Triển khai bằng `NSViewRepresentable` bọc một `NSView` first-responder nhận `keyDown` (đáng tin hơn
`.onKeyPress` của SwiftUI cho việc bắt cả modifier). Encoding tách thành **hàm thuần test được**.

---

## 6. Luồng dữ liệu & wiring

```
Khởi động:
  AppState.init → store.load() → áp inputMethod/orthography/switchKey/isVietnamese
                → controller.engine.inputMethod, .useModernOrthography
                → controller.switchKeyStatus, controller.setVietnamese(...)
  DkeyAppDelegate → EventTap.start()   (đọc controller đã cấu hình)

Người dùng đổi setting trong UI:
  TypingSettingsView → set AppState.<prop>
     didSet → (a) controller/engine áp giá trị mới  (b) store.save(snapshot)
```

**Thread-safety:** event tap chạy ở thread callback, đọc `controller.switchKeyStatus`/`engine`;
UI ghi từ main thread. Giữ đúng pattern hiện có (app đã mutate `controller` từ main thread cho
`setVietnamese`). Các giá trị là `Int32`/`Bool`/enum nhỏ, đổi lúc chuyển từ (word boundary) là an
toàn thực dụng; ghi chú là điểm rủi ro thấp, không mở rộng lock trong feature này.

---

## 7. Chiến lược test

### 7.1 Curated VNI (`Tests/EngineTests/VNITests.swift` — mới)
Bộ case viết tay song song bộ Telex hiện có, đặt `engine.inputMethod = .vni`:
- Dấu: `a1→á a2→à a3→ả a4→ã a5→ạ`
- Mũ/móc/ă: `a6→â e6→ê o6→ô o7→ơ u7→ư a8→ă`; `d9→đ`, `d9`+`a2`→`đà`
- Xóa dấu: `a1` rồi `0` → `a`; toggle-off gõ lại phím dấu
- Cụm đa nguyên âm + dấu cuối: ví dụ `viet65`… → `việt` (thứ tự phím theo OpenKey)
- Fallthrough: phím số khi không có nguyên âm hợp lệ → ký tự thô (`abc1` giữ `1`)

### 7.2 VNI parity corpus
- Mở rộng `scripts/openkey-oracle/oracle.cpp`: nhận tham số chọn `vInputType` (0=Telex, 1=VNI); khi
  VNI, map ký tự số `0-9` → keycode số. Giữ nguyên đường Telex.
- Thêm `scripts/gen-parity-corpus.sh` (hoặc script chị em) sinh `Tests/Fixtures/parity-corpus-vni.json`
  từ wordlist VNI-keystroke. **Oracle định nghĩa đáp án** (không tự bịa golden).
- `Tests/ParityTests/ParityTests.swift`: nạp thêm corpus VNI, drive `TelexEngine` với `.vni`, so chuỗi
  cuối == golden (cả modern & classic). Corpus commit vào repo (test chạy offline).

### 7.3 Persistence & recorder (thuần, không AppKit)
- `SettingsStore` round-trip: save → load == nguyên gốc; thiếu key → trả `defaults`; JSON hỏng →
  fallback `defaults` (không crash).
- KeyRecorder **encode/decode bitfield**: hàm thuần, ví dụ `(keyCode=0x06, ⌥, 'z') → 0x7A000206`;
  reject khi không có modifier.

### 7.4 Không hồi quy
Toàn bộ parity Telex + 58 test hiện tại phải **xanh** sau refactor (điều kiện chặn merge).

---

## 8. Mặc định & YAGNI
- Mặc định: kiểu gõ **Telex**, kiểu bỏ dấu **Mới**, phím chuyển **⌥Z** (`0x7A000206`), Tiếng Việt **bật**.
- KHÔNG thêm: bảng mã output, macro, auto-caps, spell-check, quick-telex, per-app, login item,
  Simple Telex/VIQR. Mỗi thứ thuộc feature/phase riêng.

---

## 9. Rủi ro & open questions
- **Chọn nguyên âm nhận mũ/móc trong VNI:** nhánh dễ lệch nhất; bám sát OpenKey + phủ bằng parity
  corpus. Cần chú ý toggle-off và fallthrough.
- **Reverse-map wordlist → keystroke VNI** cho corpus: sai chỉ giảm độ phủ, không sai đáp án (oracle
  định nghĩa golden). Nguồn wordlist chốt ở bước plan (tái dùng nguồn Telex nếu được).
- **KeyRecorder trên SwiftUI:** dùng `NSViewRepresentable` để bắt chắc modifier; xác minh first-responder
  hoạt động trong Window Settings.
- **Đồng bộ `useModernOrthography`:** hiện là property của `TelexEngine`, chưa expose ở `AppState` —
  feature này thêm đường nối + persist.

---

## 10. Self-review
- **Phạm vi:** đủ nhỏ cho một implementation plan (chỉ VNI + tab Kiểu gõ + persistence chung). ✅
- **Nhất quán:** module (mục 3) khớp UI (mục 4), wiring (mục 6), test (mục 7); bitfield mô tả một
  format duy nhất ở mục 5 khớp `HotkeyMatcher`/`hotkeyDescription`. ✅
- **Không placeholder:** mọi mục có nội dung cụ thể; 2 open question (wordlist VNI, first-responder)
  là việc xác minh khi plan, không phải lỗ hổng thiết kế. ✅
- **Không mơ hồ:** ánh xạ phím VNI, format bitfield, ranh giới HOÃN đều nêu rõ. ✅
