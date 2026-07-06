# dkey Phase 3b — Feature "Giới thiệu" (About) Design Spec

**Ngày:** 2026-07-06
**Trạng thái:** Đã brainstorm & duyệt design — chờ user review spec trước khi viết plan.
**Phase trước:** Kiểu gõ (Telex + VNI) — đã merge `main` (PR #1).

Feature thứ 2 trong 5 sub-project hướng tới **feature-parity với OpenKey**
(Giới thiệu → Chuyển mã → Gõ tắt → Hệ thống → Typing-extras), làm tuần tự,
mỗi cái một spec → plan → impl.

---

## 1. Mục tiêu

Biến tab **"Giới thiệu"** từ placeholder thành một trang About tĩnh, gọn, đúng chuẩn macOS:
tên app, phiên bản, giấy phép + credit OpenKey (bắt buộc theo GPL), và link mã nguồn.

### Phạm vi — TRONG
- Icon app + tên **dkey** + tagline "Bộ gõ Tiếng Việt cho macOS".
- **Phiên bản** đọc từ `Bundle.main` — `CFBundleShortVersionString` + `CFBundleVersion`, hiển thị `"0.1.0 (1)"`.
- Dòng **license**: "Giấy phép GPL v3 · Engine port từ OpenKey (Tuyen Mai)".
- 2 nút mở link (bằng `NSWorkspace.shared.open`):
  - **Mã nguồn dkey** → `https://github.com/datnm555/dkey`
  - **OpenKey** → `https://github.com/tuyenvm/OpenKey`

### Phạm vi — HOÃN
Kiểm tra cập nhật (network), donate, acknowledgements dài, copyright chi tiết. Không làm ở đây.

### Success criteria
1. Chọn tab Giới thiệu → hiển thị icon, tên, đúng phiên bản đọc từ bundle, dòng GPL+OpenKey, 2 nút link mở đúng URL.
2. `AppInfo.versionString(from:)` format đúng và có fallback khi thiếu key.
3. Build sạch; không đụng engine; toàn bộ test cũ vẫn xanh.

---

## 2. Quyết định kiến trúc

- **Tách logic thuần khỏi view** để test được: `AppInfo` (đọc + format version từ một info dictionary)
  là struct thuần, `AboutView` chỉ render. View không unit-test (giống `KeyRecorderField`) — build-verified + smoke.
- **Attribution GPL là bắt buộc**: engine dkey là port faithful GPL v3 từ OpenKey → About phải nêu license
  GPL v3 và credit OpenKey/Tuyen Mai. Không phải tuỳ chọn.
- Không thêm persistence/engine state — trang tĩnh, chỉ đọc `Bundle.main` + mở URL.

---

## 3. Thay đổi theo module (`Sources/App/`)

| File | Thay đổi |
|---|---|
| `AppInfo.swift` *(mới)* | `struct AppInfo { let version: String; let build: String }`; `static func versionString(from info: [String: Any]?) -> String` → `"<short> (<build>)"`, fallback `"—"` khi thiếu; `static var current: AppInfo` đọc `Bundle.main.infoDictionary`. |
| `Views/AboutView.swift` *(mới)* | SwiftUI view: `Image(nsImage: NSApp.applicationIconImage)`, tên + tagline, `AppInfo.current` version, dòng GPL+OpenKey, 2 nút link (`Link` hoặc `Button` + `NSWorkspace.open`). |
| `Views/SettingsRootView.swift` *(sửa)* | Thêm nhánh `case .about: AboutView()` vào `switch` (hiện chỉ `.typing` được route; các case khác vẫn placeholder). |

---

## 4. UI (tab Giới thiệu)

```
        [ App Icon 64pt ]
            dkey
   Bộ gõ Tiếng Việt cho macOS
       Phiên bản 0.1.0 (1)

 Giấy phép GPL v3 · Engine port từ
        OpenKey (Tuyen Mai)

   [ Mã nguồn dkey ]  [ OpenKey ]
```
Căn giữa, `VStack` spacing chuẩn, `.frame(maxWidth:)` hợp lý. Nút link style `.link`/`.bordered`.

---

## 5. Testing

- `Tests/AppTests/AppInfoTests.swift` *(mới)*:
  - `versionString(from: ["CFBundleShortVersionString":"0.1.0","CFBundleVersion":"1"]) == "0.1.0 (1)"`
  - thiếu key / nil → fallback `"—"` (không crash).
- `AboutView` + `SettingsRootView` route: build-verified (BUILD SUCCEEDED) + smoke thủ công (mở tab, bấm 2 link).
- Không hồi quy: toàn bộ test hiện có vẫn xanh.
- Nhắc: file mới → chạy `xcodegen generate` trước khi build (đã ghi memory).

---

## 6. Self-review
- **Phạm vi:** đủ nhỏ cho 1 plan (trang tĩnh + 1 helper thuần). ✅
- **Nhất quán:** module (mục 3) khớp UI (mục 4) + test (mục 5). ✅
- **Không placeholder:** URL, version keys, format string đều cụ thể. ✅
- **Không mơ hồ:** attribution GPL bắt buộc; ranh giới HOÃN rõ. ✅
