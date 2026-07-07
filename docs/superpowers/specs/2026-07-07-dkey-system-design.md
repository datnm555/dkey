# dkey Phase 5 — Feature "Hệ thống" (System) Design Spec

**Ngày:** 2026-07-07
**Trạng thái:** Đã brainstorm & duyệt design — chờ user review spec trước khi viết plan.
**Phase trước:** Kiểu gõ, Giới thiệu, Chuyển mã, Gõ tắt — đã merge `main`.

Feature thứ 5 (cuối) trong loạt hướng tới feature-parity với OpenKey. Sau feature này
chỉ còn "Typing-extras" (các cờ engine phụ cho tab Kiểu gõ).

---

## 1. Mục tiêu

Biến tab **"Hệ thống"** thành nơi cấu hình hành vi app ở mức hệ thống: biểu tượng menu bar/Dock,
khởi động cùng máy, tự nhớ chế độ gõ theo app (smart-switch), và khôi phục cài đặt mặc định.

### Phạm vi — TRONG
- **Biểu tượng đơn sắc** menu bar (`grayIcon` — cờ đã có, `StatusIcon` đã hỗ trợ; chỉ thêm UI + persist).
- **Hiện icon ở Dock** (`showIconOnDock` → `NSApp.setActivationPolicy(.regular/.accessory)`).
- **Hiện cửa sổ Cài đặt khi khởi động** (`showUIOnStartup`).
- **Khởi động cùng máy** (`runOnStartup` → `SMAppService.mainApp.register()/unregister()`; framework đã link).
- **Smart-switch**: tự nhớ Vi/En theo từng app (`useSmartSwitchKey`) — theo dõi app focus, khôi phục ngôn ngữ đã nhớ khi đổi app, ghi nhớ khi người dùng đổi ngôn ngữ.
- **Khôi phục cài đặt mặc định** (reset toàn bộ `DkeySettings` về `defaults`, có dialog xác nhận).

### Phạm vi — HOÃN / KHÔNG làm (YAGNI)
Gửi phím từng bước, tương thích layout non-QWERTY, fix trình duyệt, tạm-tắt-bằng-hotkey, nhớ bảng mã theo app
(dkey chưa có live code-table nên N/A), backup/restore ra file.

### Success criteria
1. 5 toggle hoạt động + lưu qua các lần mở app; icon đơn sắc/Dock đổi ngay.
2. Bật "Khởi động cùng máy" → dkey xuất hiện trong System Settings → Login Items; tắt → biến mất.
3. Smart-switch bật: đổi ngôn ngữ ở app A (⌥Z), chuyển sang app B rồi quay lại A → A tự về ngôn ngữ đã đặt; không có vòng lặp.
4. Khôi phục mặc định → mọi cài đặt về defaults.
5. `TelexEngine` không đổi; toàn bộ test hiện có (124) vẫn xanh.

---

## 2. Quyết định kiến trúc

- **Toggle → `DkeySettings`**: thêm 5 field Bool (backward-compat qua `decodeIfPresent` đã có), publish + apply ở `AppState` theo đúng pattern `_isReflecting`/`persist()`.
- **Tách lõi thuần khỏi glue hệ thống**:
  - `SmartSwitch` = **lõi thuần test được** (map `[bundleId: Bool]` + persist), KHÔNG chứa `NSWorkspace`. Việc quan sát app-focus + áp ngôn ngữ nằm ở `AppState` (glue).
  - `LoginItem` = wrapper mỏng quanh `SMAppService` (system call), tách khỏi UI.
- **Engine không đổi**: mọi thứ ở lớp App/Platform. Smart-switch chỉ gọi `controller.setVietnamese` + reflect vào UI — không đụng logic gõ.

---

## 3. Thay đổi theo module

### 3.1 Lõi thuần
| File | Trách nhiệm |
|---|---|
| `Sources/Platform/SmartSwitch.swift` *(mới)* | `final class SmartSwitch { var isEnabled: Bool; func languageFor(_ bundleId: String) -> Bool?; func remember(_ bundleId: String, vietnamese: Bool); func reset() }`. Map `[String: Bool]` persist qua `UserDefaults` (key `dkey.smartswitch.v1`, JSON). Thuần — không `NSWorkspace`. |

### 3.2 App
| File | Thay đổi |
|---|---|
| `LoginItem.swift` *(mới)* | `enum LoginItem { static var isEnabled: Bool { get }; static func setEnabled(_:) }` bọc `SMAppService.mainApp` (register/unregister; try/catch nuốt lỗi, log). |
| `DkeySettings.swift` *(sửa)* | Thêm `grayIcon`, `showIconOnDock`, `showUIOnStartup`, `runOnStartup`, `useSmartSwitchKey` (Bool). `defaults` = false hết. Decoder `decodeIfPresent ?? false` cho 5 field mới. |
| `AppState.swift` *(sửa)* | Đưa `grayIcon` vào persist; thêm 4 published toggle + `smartSwitch: SmartSwitch`; `currentBundleId`. didSet: `showIconOnDock`→activationPolicy; `runOnStartup`→`LoginItem.setEnabled`; `useSmartSwitchKey`→`smartSwitch.isEnabled`; tất cả persist. Quan sát `NSWorkspace.didActivateApplicationNotification`. `resetToDefaults()`. |
| `Views/SystemView.swift` *(mới)* | 5 toggle + nút "Khôi phục cài đặt mặc định" (confirm). |
| `Views/SettingsRootView.swift` *(sửa)* | `case .system: SystemView()`. |
| `DkeyApp.swift` *(sửa)* | Lúc launch: nếu `showUIOnStartup` → mở window settings; áp `activationPolicy` ban đầu theo `showIconOnDock`. |

---

## 4. Smart-switch — ngữ nghĩa & chống vòng lặp

- **Trạng thái**: `smartSwitch` giữ `[bundleId: Bool]` (Vi=true/En=false). `AppState.currentBundleId` = app đang focus.
- **Khi đổi app** (`didActivateApplicationNotification`): cập nhật `currentBundleId`. Nếu `useSmartSwitchKey` và `smartSwitch.languageFor(id) != nil` → **áp** ngôn ngữ nhớ: đặt cờ `restoringForApp = true`, gọi `controller.setVietnamese(nhớ)` + reflect `isVietnamese` (để icon/menu cập nhật), rồi `restoringForApp = false`. **Không remember** trong nhánh này.
- **Khi user đổi ngôn ngữ** (hotkey ⌥Z qua `onLanguageChanged`, hoặc menu toggle): nếu `useSmartSwitchKey` và **không** `restoringForApp` → `smartSwitch.remember(currentBundleId, isVietnamese)`.
- Cờ `restoringForApp` tách khỏi `_isReflecting` (rõ ràng: `_isReflecting` = "đừng re-notify engine/persist khi phản chiếu"; `restoringForApp` = "đừng ghi nhớ khi đang khôi phục"). Ngăn vòng restore↔remember.

---

## 5. Login item & Dock/UI

- **Login item**: `SMAppService.mainApp.register()` (bật) / `.unregister()` (tắt). `isEnabled` đọc `SMAppService.mainApp.status == .enabled`. Lỗi (chưa notarize v.v.) → log, không crash; UI phản ánh trạng thái thực khi mở tab.
- **Dock**: `showIconOnDock` true → `.regular` (hiện Dock), false → `.accessory` (chỉ menu bar). Áp lúc launch + khi đổi.
- **Show UI on startup**: launch → nếu bật, `openWindow(id:"settings")` + activate.
- **Reset**: `resetToDefaults()` gán từng field từ `DkeySettings.defaults` (dưới `_isReflecting` rồi apply + persist), dialog xác nhận trong `SystemView`.

---

## 6. Persistence
- 5 toggle trong `DkeySettings` (JSON UserDefaults sẵn có). Smart-switch map riêng (`dkey.smartswitch.v1`).

---

## 7. UI (tab Hệ thống)
```
Biểu tượng
  [x] Biểu tượng đơn sắc trên menu bar
  [ ] Hiện biểu tượng ở Dock
Khởi động
  [ ] Khởi động cùng máy
  [ ] Hiện cửa sổ Cài đặt khi khởi động
Thông minh
  [ ] Tự nhớ chế độ gõ theo từng ứng dụng
──────────────
[ Khôi phục cài đặt mặc định ]   (confirm dialog)
```

## 8. Testing
- `SmartSwitchTests` (thuần): remember/languageFor; unknown → nil; persist round-trip; reset.
- `DkeySettings` round-trip 5 field mới + `resetToDefaults` đưa AppState về defaults.
- `LoginItem`: logic wrapper (system call không unit-test được — kiểm phần quyết định/không crash).
- Smart-switch anti-loop: curated test ở tầng AppState-logic (map + restoringForApp) mô phỏng đổi app + đổi ngôn ngữ, khẳng định không remember khi restore.
- Không hồi quy engine (124 test) + build sạch.

## 9. YAGNI
- Chỉ 5 toggle + reset + smart-switch + login item. Hoãn mọi niche ở §1.

## 10. Self-review
- **Phạm vi:** một tab, nhiều thành phần nhỏ chung `DkeySettings`; đủ cho 1 plan chia task. ✅
- **Nhất quán:** module (§3) ↔ smart-switch (§4) ↔ login/dock (§5) ↔ test (§8). ✅
- **Không placeholder:** API SmartSwitch/LoginItem, cờ chống loop, activationPolicy cụ thể. ✅
- **Rủi ro:** vòng lặp smart-switch (chặn bằng `restoringForApp`, có test); SMAppService có thể fail nếu app chạy từ DerivedData chưa notarize — UI phản ánh trạng thái thực, không crash.
