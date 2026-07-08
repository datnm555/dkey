# dkey Redesign — Foundation + Screen ① Onboarding Design Spec

**Ngày:** 2026-07-08
**Trạng thái:** Đã brainstorm & duyệt design — chờ user review spec trước khi viết plan.
**Bối cảnh:** Redesign UI 6 màn theo `DKey Mockups.standalone.html`. Chức năng lõi (Telex/VNI, macro, convert, smart-switch, about) đã xây xong + merge `main`. Loạt này là **lớp redesign UI + polish 1.0**, làm **tuần tự per-screen**.

Sub-project đầu: **Foundation (theme dùng chung) + màn Onboarding** (chào mừng + cấp quyền Trợ năng).

---

## 1. Mục tiêu

Dựng **nền visual dùng chung** (palette + màu accent lấy từ mockup) và màn **Onboarding** đầu tiên:
chào mừng + hướng dẫn cấp quyền Accessibility, thay cho prompt hệ thống thô hiện tại.

### Phạm vi — TRONG
- **`Theme`**: bảng màu từ mockup (nền ấm `#faf9f5`, panel `#f5f5f7`, text `#1d1d1f`, phụ `#86868b`, **accent `#5ba7f7`**, success `#28c840`) qua `Color` extension + hex init. Dùng chung cho các màn sau.
- **Màn Onboarding** (cửa sổ riêng, id `"onboarding"`): logo DKey + "Chào mừng đến với DKey" + card cấp quyền (đường dẫn `System Settings → Privacy & Security → Accessibility`), nút **"Mở System Settings"** (deep-link), trạng thái quyền **live** (tick xanh khi được cấp), nút phụ **"Để sau"**.
- Auto-mở onboarding lúc launch **nếu chưa hoàn tất** (`hasCompletedOnboarding == false`); hoàn tất/"Để sau" → set cờ, không hiện lại.
- Cờ `hasCompletedOnboarding` trong `DkeySettings` (decodeIfPresent, default false).

### Phạm vi — HOÃN (màn/sub-project sau)
Popover chính, redesign 5 tab, per-app UI, update-check, accent-color picker, browser-fix. Không làm ở đây.
Reusable `SectionCard`/`SettingRow` sẽ thêm khi màn sau cần (YAGNI) — sub-project này chỉ cần `Theme` + view onboarding.

### Success criteria
1. Lần chạy đầu (hoặc chưa hoàn tất onboarding) → cửa sổ Onboarding tự mở.
2. "Mở System Settings" mở đúng pane Accessibility; khi cấp quyền → tick xanh live (poll `AXIsProcessTrusted`).
3. "Bắt đầu"/"Để sau" → set `hasCompletedOnboarding`, đóng window, lần sau không auto-mở.
4. `Theme` màu khớp mockup; không đụng engine; toàn bộ test hiện có (133) vẫn xanh.

---

## 2. Quyết định kiến trúc

- **Tách logic thuần khỏi view**: quyết định "có auto-mở onboarding không" + màu hex→Color là hàm thuần, test được; view + window wiring build-verified + smoke.
- **Dùng lại hạ tầng quyền sẵn có**: `PermissionMonitor` (`isTrusted`, `waitUntilTrusted`, `prompt`) — không viết lại; onboarding chỉ là UI đẹp bọc lên.
- **Không đụng engine**; mọi thứ ở `Sources/App`.
- **Theme tối giản**: chỉ màu (SwiftUI native lo control). Component tái dùng thêm dần theo nhu cầu màn sau.

---

## 3. Thay đổi theo module (`Sources/App/`)

| File | Trách nhiệm |
|---|---|
| `Theme.swift` *(mới)* | `extension Color { init(hex:) ; static let dkWindowBg/dkPanel/dkText/dkSecondary/dkAccent/dkSuccess }`. Palette từ mockup. |
| `Onboarding.swift` *(mới)* | Logic thuần: `enum Onboarding { static func shouldAutoOpen(completed: Bool) -> Bool ; static let accessibilitySettingsURL: URL }`. |
| `Views/OnboardingView.swift` *(mới)* | SwiftUI view màn onboarding (logo, welcome, card cấp quyền, nút Mở System Settings / Bắt đầu / Để sau); poll `PermissionMonitor.isTrusted`; gọi `state.completeOnboarding()`/`dismissWindow`. |
| `DkeySettings.swift` *(sửa)* | Thêm `hasCompletedOnboarding: Bool` (default false, decodeIfPresent). |
| `AppState.swift` *(sửa)* | `@Published var hasCompletedOnboarding` (persist); `func completeOnboarding()` set true + persist. |
| `DkeyApp.swift` *(sửa)* | Thêm `Window("Chào mừng", id: "onboarding") { OnboardingView() }`; auto-mở ở launch (qua `MenuBarLabel.onAppear` — đã có pattern show-UI-on-startup) nếu `Onboarding.shouldAutoOpen(completed:)`. |

---

## 4. Luồng Onboarding

```
launch → MenuBarLabel.onAppear (chạy 1 lần)
  nếu Onboarding.shouldAutoOpen(completed: state.hasCompletedOnboarding) → openWindow("onboarding") + activate
OnboardingView:
  Trạng thái quyền = PermissionMonitor.isTrusted (poll qua Timer/waitUntilTrusted)
    chưa cấp → card + nút "Mở System Settings" (mở accessibilitySettingsURL) + "Để sau"
    đã cấp  → tick xanh "Đã cấp quyền" + nút "Bắt đầu"
  "Bắt đầu"/"Để sau" → state.completeOnboarding() + dismiss window
```
- `accessibilitySettingsURL` = `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
- Poll: dùng `PermissionMonitor.waitUntilTrusted { … }` (đã có) để cập nhật `@State isTrusted` khi user cấp quyền ngoài app → tick xanh không cần bấm lại.

---

## 5. Testing
- `ThemeTests`: `Color(hex: 0xFAF9F5)` (hoặc "#faf9f5") ra đúng thành phần RGB kỳ vọng; vài hằng màu khác giá trị đúng.
- `OnboardingTests`: `shouldAutoOpen(completed: false) == true`, `shouldAutoOpen(completed: true) == false`; `accessibilitySettingsURL` không nil và đúng scheme.
- `DkeySettings` round-trip có `hasCompletedOnboarding`.
- `OnboardingView` + window wiring: BUILD SUCCEEDED + smoke thủ công (deferred user: lần đầu mở, cấp quyền → tick, Bắt đầu → đóng, relaunch không mở lại).
- Không hồi quy engine (133 test).

## 6. YAGNI
Chỉ Theme (màu) + onboarding. Không component library, không accent-picker, không redesign tab.

## 7. Self-review
- **Phạm vi:** 1 sub-project nhỏ (theme + 1 màn). Đủ cho 1 plan. ✅
- **Nhất quán:** module (§3) ↔ luồng (§4) ↔ test (§5). ✅
- **Không placeholder:** URL deep-link, palette hex, quyết định auto-open cụ thể. ✅
- **Rủi ro:** window auto-open ở launch (dùng pattern show-UI-on-startup đã có); deep-link pane có thể đổi theo macOS version — nút vẫn mở System Settings (không crash).
