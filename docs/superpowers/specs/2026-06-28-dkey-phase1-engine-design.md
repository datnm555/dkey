# dkey Phase 1 — Telex Engine Design Spec

**Ngày:** 2026-06-28
**Trạng thái:** Đã brainstorm & duyệt design — sẵn sàng viết implementation plan.
**Phase trước:** Phase 0 (scaffold) đã merge vào `main`.

---

## 1. Mục tiêu

Xây **engine gõ Telex thuần Swift** cho dkey: nhận keystroke, đặt dấu thanh/dấu phụ đúng vị trí, xuất ký tự **Unicode NFC**. Engine không phụ thuộc AppKit, test được độc lập, và **khớp byte-for-byte với OpenKey** trên một parity corpus.

### Phạm vi — TRONG Phase 1
- Gõ Telex: phụ âm + nguyên âm.
- Dấu mũ: `â/ê/ô` (gõ `aa/ee/oo`).
- Dấu móc & ă: `ơ/ư` (gõ `ow/uw` hoặc `w`), `ă` (gõ `aw`).
- `đ` (gõ `dd`).
- Dấu thanh sắc/huyền/hỏi/ngã/nặng (`s/f/r/x/j`) — đặt đúng nguyên âm trong cụm.
- Toggle **modern/classic orthography** (`hòa` ↔ `hoà`).
- Undo dấu (gõ phím dấu lần 2 để huỷ), `z` xoá mọi dấu, gõ phím mũ/móc lần 2 để restore.
- Đặt lại dấu khi backspace (`checkGrammar`).
- Output **Unicode NFC** (precomposed, 1 codepoint/ký tự).

### Phạm vi — HOÃN (phase sau)
VNI, simple-telex 1/2, spell-check + restore-if-wrong-spelling, quick-telex (`cc→ch`…), quick start/end consonant (`f→ph`, `g→ng`…), codepage TCVN3/VNI/VIQR/VPS/CP1258, macro, smart-switch, free-mark, auto-caps, event-tap & key synthesis (Phase 2).

### Success criteria
1. Curated XCTest (vài chục case) xanh — phủ thanh, mũ, móc, đ, đặt dấu modern/classic, undo, z, đa nguyên âm, backspace re-correct.
2. ParityTests: chuỗi output của `TelexEngine` **khớp golden** sinh từ OpenKey trên toàn corpus (cả modern & classic).
3. `Sources/Engine` build sạch trong target `dkey` mà **không** kéo theo C++/bridge vào app.

---

## 2. Bối cảnh & quyết định kiến trúc

- dkey và mkey **đều base trên OpenKey** (engine C++ của Tuyen Mai, GPL v3). Khác biệt: mkey *bọc* engine C++ qua ObjC++ bridge; dkey *port* sang Swift thuần.
- License dkey **đã là GPL v3** (đã commit ở Phase 0) → port trực tiếp từ OpenKey là hợp lệ. mkey chỉ dùng làm **tài liệu tham khảo**.
- **Quyết định: Hướng B — port faithful, pure Swift.** Dịch sát thuật toán + mô hình mask-buffer của OpenKey sang Swift, nhưng bọc bằng API Swift sạch (instance, protocol, không global).
  - Lý do: oracle parity chính là OpenKey → mirror logic của nó là cách an toàn nhất để khớp; thuật toán Telex tinh vi, redesign-while-guessing dễ lệch edge-case; sau khi xanh parity có thể refactor dần sang Swift sạch hơn với corpus làm lưới an toàn.

### Nguyên tắc "vỏ sạch, ruột faithful"
- **Vỏ (public):** `protocol InputEngine` + instance `TelexEngine`. Cấu hình là property (vd `useModernOrthography`) thay cho global `extern int` của OpenKey. Mock-able, test-able.
- **Ruột (internal):** buffer `TypingWord` + bit-mask + control-flow mirror OpenKey 1:1 để giữ parity.

---

## 3. Kiến trúc module — `Sources/Engine/` (pure Swift, KHÔNG import AppKit)

| File | Trách nhiệm |
|---|---|
| `KeyCode.swift` | Hằng mã phím độc lập phần cứng (`KEY_A`…`KEY_Z`, `KEY_SPACE`, `KEY_BACKSPACE`, `[`, `]`…). Tách khỏi CGKeyCode — Phase 2 sẽ map `CGKeyCode → KeyCode`. |
| `EngineMasks.swift` | Hằng bit-mask port từ `DataType.h`: `CAPS_MASK`, `TONE_MASK`, `TONEW_MASK`, `MARK1..5_MASK`, `MARK_MASK`, `STANDALONE_MASK`, `CHAR_CODE_MASK`, `CHAR_MASK`… + helper đọc/ghi mask trên ô `UInt32`. |
| `VietnameseTables.swift` | Port nguyên các bảng dữ liệu OpenKey (nguồn chân lý): `_vowel`, `_vowelCombine`, `_vowelForMark`, `_consonantD`, và **chỉ bảng Unicode NFC** (`_codeTable[0]`) + `_unicodeCompoundMark` nếu cần, `keyCodeToCharacter`. |
| `TypingBuffer.swift` | Mô hình `TypingWord[MAX_BUFF=32]` + `_index`: mảng ô `UInt32` với accessor đọc/ghi mask rõ ràng (vỏ Swift, ruột mask 1:1). |
| `TelexEngine.swift` | **Lõi.** Port faithful các hàm: `vKeyHandleEvent`, `handleMainKey`, `insertMark`, `insertAOE`, `insertW`, `insertD`, `removeMark`, `handleModernMark`, `handleOldMark`, `findAndCalculateVowel`, `checkGrammar`, `getCharacterCode`, `startNewSession`. |
| `InputEngine.swift` | Protocol công khai + `struct EngineOutput` + `enum Action`. `TelexEngine` conform. |

Mỗi file một trách nhiệm rõ. Nếu `TelexEngine.swift` phình to khi port, được phép tách theo nhóm hàm (vd `TelexEngine+Mark.swift`, `TelexEngine+Diacritic.swift`) — quyết định ở bước plan.

---

## 4. API công khai (`InputEngine.swift`)

```swift
public enum Action: Equatable {
    case passthrough   // không biến đổi (vDoNothing)
    case process       // có biến đổi (vWillProcess)
    case wordBreak     // ngắt từ (vBreakWord)
    case restore       // huỷ/khôi phục (vRestore)
}

public struct EngineOutput: Equatable {
    public let backspaceCount: Int          // số ký tự cần xoá lùi
    public let newChars: [Unicode.Scalar]   // ký tự thay thế (NFC), theo THỨ TỰ HIỂN THỊ
    public let action: Action
}

public protocol InputEngine: AnyObject {
    func handle(key: KeyCode, caps: Bool) -> EngineOutput
    func backspace() -> EngineOutput
    func newSession()                       // space / chuyển từ / mất focus
    var useModernOrthography: Bool { get set }
}

public final class TelexEngine: InputEngine { /* … */ }
```

- **Input = keycode + caps** (đúng `vKeyHandleEvent`). Engine không biết CGEvent.
- **Output đã sạch hoá:** OpenKey điền `charData[]` theo *thứ tự ngược*; ta đảo nội bộ để `newChars` theo thứ tự đọc. `action` map từ `HoolCodeState`.
- Engine giữ toàn bộ state trong instance (không global). Nhiều instance độc lập (tốt cho test).

---

## 5. Luồng dữ liệu

```
[Phase 2: EventTap]  CGEvent keyDown
        │  map → KeyCode + caps
        ▼
engine.handle(key:caps:)  ──►  EngineOutput{ backspaceCount, newChars, action }
        │
        ▼
[Phase 2]  gửi N backspace, rồi chèn newChars
```

Phase 1 **chỉ** dựng engine + trả `EngineOutput` đúng. Việc "gửi backspace / chèn ký tự" thuộc Phase 2. Test Phase 1 kiểm tra trực tiếp `EngineOutput` (hoặc chuỗi cuối sau khi apply output vào buffer giả).

---

## 6. Xử lý phím (trong `handle`)

| Loại phím | Hành vi |
|---|---|
| Phím ngắt từ (space, `. , ; : " ' ( ) ! ?`…, Enter, Tab, mũi tên) | Kết thúc từ → `newSession()`, `action=.wordBreak`, không biến đổi |
| Backspace | `backspace()`: lùi `_index`, chạy `checkGrammar` đặt lại dấu cho đúng sau khi xoá |
| Phím Telex đặc biệt (`w a e o s d f j z x [ ]`) hợp lệ ngữ cảnh | `handleMainKey` → `insertMark`/`insertAOE`/`insertW`/`insertD`/`removeMark` |
| Phím thường khác | Chèn ký tự thô vào buffer |

### Đặt dấu thanh (mấu chốt parity)
- `findAndCalculateVowel` xác định cụm nguyên âm (`VSI`/`VEI`/số nguyên âm).
- `handleModernMark` vs `handleOldMark` chọn nguyên âm nhận dấu theo `useModernOrthography`. Map cờ **đúng theo OpenKey** (`vUseModernOrthography`: `0 → òa/úy`, `1 → oà/uý`).
- Gõ dấu trùng → huỷ dấu (`action=.restore`); `z` → xoá mọi dấu trong cụm.

---

## 7. Mô hình buffer & output

### Buffer (port `DataType.h`)
Mỗi ô `TypingWord[i]` là `UInt32` mã hoá: bit 0–15 keycode; bit 16 `CAPS`; bit 17 `TONE` (mũ â/ê/ô); bit 18 `TONEW` (móc ơ/ư); bit 19–23 `MARK1..5` (5 thanh); bit 24 `STANDALONE`; bit 25 `CHAR_CODE`. `_index` là vị trí hiện tại (0…31).

### Output Unicode NFC (`getCharacterCode`)
- Tra `_codeTable[0]` (Unicode precomposed) bằng key = `keycode | TONE_MASK | TONEW_MASK`, index = `2×capsElem + markIndex`.
- Phase 1 **chỉ** dùng bảng Unicode NFC; các codepage khác (`_codeTable[1..4]`) hoãn sang Phase 3.

---

## 8. Chiến lược test (hybrid parity)

### Tầng 1 — Curated tests (`Tests/EngineTests/`)
Vài chục case viết tay (regression + tài liệu), kiểm chuỗi cuối / `EngineOutput`:
- Thanh: `as→á af→à ar→ả ax→ã aj→ạ`
- Mũ: `aa→â aas→ấ ee→ê oo→ô`; móc/ă: `uw→ư ow→ơ aw→ă`, `w→ư`; đ: `dd→đ ddaf→đà`
- Đặt dấu modern/classic: `hoaf` → `hòa` (mới) vs `hoà` (cũ); `uys→úy` vs `uý`
- Cụm đa nguyên âm: `oai uyen uong`
- Undo/z: gõ dấu lần 2 huỷ; `z` xoá dấu; mũ/móc lần 2 restore
- Backspace re-correct: gõ `hoà` rồi xoá → dấu nhảy lại đúng (`checkGrammar`)

### Tầng 2 — Parity corpus sinh từ OpenKey
```
scripts/openkey-oracle/
   build.sh            clang++ -std=c++17, compile ../mkey/Sources/Engine (phần engine thuần)
   oracle.cpp          nhận chuỗi Telex + cờ orthography; drive vKeyHandleEvent từng phím;
                       dựng lại chuỗi output cuối
scripts/gen-parity-corpus.sh   chạy oracle trên wordlist → Tests/Fixtures/parity-corpus.json
Tests/Fixtures/parity-corpus.json   COMMIT vào repo (test chạy offline, không cần C++)
Tests/ParityTests/     load JSON; drive TelexEngine y hệt từng phím; assert chuỗi cuối == golden
```

**Điểm thiết kế:**
- **Oracle ĐỊNH NGHĨA đáp án** — không tự bịa "đáp án đúng" (tránh tự bake lỗi). Mỗi input chạy cho **cả modern & classic** → record `{input, modern, classic}`.
- **Nguồn input** = (a) tổ hợp có cấu trúc (phụ âm đầu × cụm nguyên âm × phím dấu × phụ âm cuối) phủ edge-case + (b) wordlist âm tiết tiếng Việt thật reverse-map ra keystroke. Reverse-map sai chỉ giảm độ phủ, **không** làm sai đáp án (oracle định nghĩa output).
- **So sánh chuỗi cuối** (apply backspaces+chars vào buffer giả) — đúng hợp đồng thực tế, bền với khác biệt backspace trung gian. Có thể thêm so sánh per-key ở mức chặt hơn sau.

### Tích hợp build (`project.yml`)
- Thêm `Sources/Engine` vào sources của target `dkey`.
- Thêm test `EngineTests` + `ParityTests` (fixture JSON là test resource), có thể gộp vào target `dkeyTests` hiện có.
- Oracle C++ + script sinh corpus chạy **thủ công / CI**, KHÔNG chạy mỗi lần test (test chỉ đọc JSON đã commit) → app vẫn pure-Swift.

---

## 9. Rủi ro & open questions
- **Wordlist nguồn:** cần một danh sách âm tiết tiếng Việt công khai cho corpus — chốt nguồn cụ thể khi viết plan.
- **Compile OpenKey standalone:** `DataType.h` include `platforms/mac.h`; oracle chỉ gọi phần engine thuần (không event-tap). Có thể cần stub/giữ tối thiểu vài định nghĩa platform. Xác minh khi dựng oracle.
- **Độ chi tiết port:** `TelexEngine.swift` có thể lớn; cho phép tách file theo nhóm hàm ở bước plan.
- **`checkGrammar` khi backspace:** là phần dễ lệch nhất — cần case test riêng.

---

## 10. Self-review
- **Phạm vi:** đủ nhỏ cho 1 implementation plan (chỉ Telex + NFC, hoãn mọi thứ khác). ✅
- **Nhất quán:** API (`InputEngine`/`EngineOutput`/`Action`) dùng nhất quán ở mục 4–6; bảng module (mục 3) khớp các hàm port (mục 6). ✅
- **Không placeholder:** mọi mục có nội dung cụ thể; 2 open question (wordlist, stub platform) là việc cần xác minh khi plan, không phải lỗ hổng thiết kế. ✅
- **Không mơ hồ:** cờ orthography map rõ theo OpenKey; output chốt NFC; ranh giới engine/Phase-2 rõ. ✅
