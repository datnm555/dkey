# dkey Phase 0 — Scaffold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tạo project scaffold cho `dkey` chạy được: app menu-bar (MenuBarExtra với icon V/E) + cửa sổ Settings skeleton 5 tab rỗng, build bằng `xcodebuild`, license GPL v3.

**Architecture:** Pure Swift, XcodeGen-generated `.xcodeproj`, macOS 14+. SwiftUI App với `MenuBarExtra` + `Window`. `AppState` là singleton `ObservableObject` (theo pattern đã proven của MKey, inject qua `.environmentObject`). Phase này CHƯA có engine/event-tap — chỉ scaffold + UI skeleton + toggle ngôn ngữ giả lập (đổi icon).

**Tech Stack:** Swift 6.1 / Swift 5.9 language mode, SwiftUI, AppKit, XcodeGen, xcodebuild. Không C++, không bridging header.

---

## File Structure

Tạo mới:
- `project.yml` — XcodeGen spec (pure Swift, bundle `com.datnm555.dkey`)
- `LICENSE` — thay nội dung MIT bằng GPL v3
- `Sources/Support/Info.plist` — `LSUIElement`, region `vi`, attribution OpenKey
- `Sources/Support/dkey.entitlements` — rỗng (sandbox off)
- `Sources/Support/Assets.xcassets/` — AppIcon + AccentColor placeholder
- `Sources/App/DkeyApp.swift` — `@main`, MenuBarExtra + Window + AppDelegate
- `Sources/App/AppState.swift` — singleton ObservableObject (Phase 0: chỉ `isVietnamese`, `grayIcon`, `selectedPage`, `switchKeyStatus`)
- `Sources/App/StatusIcon.swift` — render icon "V"/"E"
- `Sources/App/Views/SettingsRootView.swift` — sidebar TabView 5 tab rỗng
- `.gitignore` — bỏ qua `*.xcodeproj`, build artifacts
- `Tests/SmokeTests/SmokeTests.swift` — test scaffold compile + AppState defaults

Mỗi file 1 trách nhiệm rõ. Engine/Platform sẽ thêm ở phase sau.

---

### Task 1: Tooling + .gitignore

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Cài XcodeGen (nếu chưa có)**

Run:
```bash
which xcodegen || brew install xcodegen
xcodegen --version
```
Expected: in ra version (vd `Version: 2.x.x`). Nếu `brew` chậm, chấp nhận chờ.

- [ ] **Step 2: Tạo `.gitignore`**

Create `.gitignore`:
```gitignore
# Xcode / XcodeGen
*.xcodeproj/
*.xcworkspace/
DerivedData/
build/
*.dmg

# macOS
.DS_Store

# Swift
.build/
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore for Xcode/Swift artifacts"
```

---

### Task 2: License GPL v3

**Files:**
- Modify: `LICENSE` (thay toàn bộ)

- [ ] **Step 1: Ghi đè LICENSE bằng GPL v3 đầy đủ**

Run (tải bản chuẩn FSF):
```bash
curl -fsSL https://www.gnu.org/licenses/gpl-3.0.txt -o LICENSE
head -3 LICENSE
```
Expected: dòng đầu chứa `GNU GENERAL PUBLIC LICENSE` và `Version 3, 29 June 2007`.

Nếu không có mạng: copy `../mkey/LICENSE` (đã là GPL v3):
```bash
cp ../mkey/LICENSE LICENSE
head -3 LICENSE
```

- [ ] **Step 2: Commit**

```bash
git add LICENSE
git commit -m "license: switch dkey from MIT to GPL v3 (OpenKey port)"
```

---

### Task 3: XcodeGen project spec

**Files:**
- Create: `project.yml`

- [ ] **Step 1: Tạo `project.yml`**

Create `project.yml`:
```yaml
name: dkey
options:
  bundleIdPrefix: com.datnm555
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    CODE_SIGN_IDENTITY: "-"
    CODE_SIGN_STYLE: Manual
    DEVELOPMENT_TEAM: ""
    ENABLE_HARDENED_RUNTIME: NO

targets:
  dkey:
    type: application
    platform: macOS
    sources:
      - path: Sources/App
      - path: Sources/Support
        includes:
          - "Assets.xcassets"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.datnm555.dkey
        PRODUCT_NAME: dkey
        INFOPLIST_FILE: Sources/Support/Info.plist
        CODE_SIGN_ENTITLEMENTS: Sources/Support/dkey.entitlements
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        COMBINE_HIDPI_IMAGES: YES
    dependencies:
      - sdk: Cocoa.framework
      - sdk: ServiceManagement.framework

  dkeyTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/SmokeTests
    dependencies:
      - target: dkey
    settings:
      base:
        BUNDLE_LOADER: "$(TEST_HOST)"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/dkey.app/Contents/MacOS/dkey"
```

Note: `Sources/Engine` và `Sources/Platform` chưa thêm vào targets — sẽ bổ sung ở phase sau.

- [ ] **Step 2: Commit (project.yml — file generate ra bị gitignore)**

```bash
git add project.yml
git commit -m "build: add XcodeGen project spec (pure Swift, macOS 14)"
```

---

### Task 4: Info.plist + entitlements

**Files:**
- Create: `Sources/Support/Info.plist`
- Create: `Sources/Support/dkey.entitlements`

- [ ] **Step 1: Tạo `Sources/Support/Info.plist`**

Create `Sources/Support/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>vi</string>
	<key>CFBundleDisplayName</key>
	<string>dkey</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIconName</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>dkey</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.utilities</string>
	<key>LSMinimumSystemVersion</key>
	<string>$(MACOSX_DEPLOYMENT_TARGET)</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>Engine © Tuyen Mai (OpenKey, GPL v3). dkey 2026, GPL v3.</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 2: Tạo `Sources/Support/dkey.entitlements`**

Create `Sources/Support/dkey.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
```

- [ ] **Step 3: Commit**

```bash
git add Sources/Support/Info.plist Sources/Support/dkey.entitlements
git commit -m "build: add Info.plist (LSUIElement) and empty entitlements"
```

---

### Task 5: Assets catalog

**Files:**
- Create: `Sources/Support/Assets.xcassets/Contents.json`
- Create: `Sources/Support/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `Sources/Support/Assets.xcassets/AccentColor.colorset/Contents.json`

- [ ] **Step 1: Tạo asset catalog root**

Create `Sources/Support/Assets.xcassets/Contents.json`:
```json
{
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 2: Tạo AppIcon placeholder (rỗng, không có ảnh — build vẫn chạy)**

Create `Sources/Support/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 3: Tạo AccentColor**

Create `Sources/Support/Assets.xcassets/AccentColor.colorset/Contents.json`:
```json
{
  "colors" : [ { "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 4: Commit**

```bash
git add Sources/Support/Assets.xcassets
git commit -m "build: add asset catalog (AppIcon placeholder, AccentColor)"
```

---

### Task 6: AppState skeleton

**Files:**
- Create: `Sources/App/AppState.swift`

- [ ] **Step 1: Tạo `Sources/App/AppState.swift`**

Create `Sources/App/AppState.swift`:
```swift
import SwiftUI

/// Trang trong cửa sổ Settings.
enum SettingsPage: String, CaseIterable, Identifiable {
    case typing, macro, convert, system, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .typing:  return "Kiểu gõ"
        case .macro:   return "Gõ tắt"
        case .convert: return "Chuyển mã"
        case .system:  return "Hệ thống"
        case .about:   return "Giới thiệu"
        }
    }

    var systemImage: String {
        switch self {
        case .typing:  return "keyboard"
        case .macro:   return "text.badge.plus"
        case .convert: return "arrow.left.arrow.right"
        case .system:  return "gearshape"
        case .about:   return "info.circle"
        }
    }
}

/// Nguồn sự thật cho UI. Phase 0 mới chỉ giữ vài state UI tối thiểu;
/// các cờ engine sẽ bổ sung ở phase sau. Theo pattern proven của MKey:
/// ObservableObject singleton inject qua .environmentObject.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// ⌥Z mặc định: keyCode 0x7A=Z? Thực tế MKey lưu bitfield 0x7A000206.
    /// Phase 0 chỉ dùng để hiển thị; logic hotkey thêm sau.
    static let defaultSwitchKeyStatus: Int32 = 0x7A000206

    @Published var isVietnamese: Bool = true
    @Published var grayIcon: Bool = false
    @Published var selectedPage: SettingsPage = .typing
    @Published var switchKeyStatus: Int32 = AppState.defaultSwitchKeyStatus

    private init() {}

    /// Hiển thị hotkey dạng "⌥Z". Phase 0: rút gọn, đủ cho menu.
    static func hotkeyDescription(_ status: Int32) -> String {
        var parts = ""
        if status & 0x100 != 0 { parts += "⌃" }
        if status & 0x200 != 0 { parts += "⌥" }
        if status & 0x400 != 0 { parts += "⌘" }
        if status & 0x800 != 0 { parts += "⇧" }
        let display = UInt8((status >> 24) & 0xFF)
        if display != 0, let scalar = Unicode.Scalar(display) {
            parts += String(scalar).uppercased()
        }
        return parts
    }
}
```

- [ ] **Step 2: Build kiểm tra compile (sẽ làm ở Task 9 sau khi đủ file). Tạm commit.**

```bash
git add Sources/App/AppState.swift
git commit -m "feat: add AppState skeleton (UI state, settings pages)"
```

---

### Task 7: StatusIcon

**Files:**
- Create: `Sources/App/StatusIcon.swift`

- [ ] **Step 1: Tạo `Sources/App/StatusIcon.swift`**

Create `Sources/App/StatusIcon.swift`:
```swift
import AppKit

/// Vẽ icon menu bar: chữ "V" (tiếng Việt) hoặc "E" (English) trong khung bo góc.
enum StatusIcon {
    static func image(vietnamese: Bool, gray: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let letter = vietnamese ? "V" : "E"
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
        let color: NSColor = gray ? .labelColor : .controlAccentColor
        color.setStroke()
        path.lineWidth = 1.2
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: color,
        ]
        let str = NSAttributedString(string: letter, attributes: attrs)
        let strSize = str.size()
        let point = NSPoint(x: (size.width - strSize.width) / 2,
                            y: (size.height - strSize.height) / 2)
        str.draw(at: point)

        image.isTemplate = gray
        return image
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/App/StatusIcon.swift
git commit -m "feat: add StatusIcon (V/E menu bar icon)"
```

---

### Task 8: SettingsRootView skeleton

**Files:**
- Create: `Sources/App/Views/SettingsRootView.swift`

- [ ] **Step 1: Tạo `Sources/App/Views/SettingsRootView.swift`**

Create `Sources/App/Views/SettingsRootView.swift`:
```swift
import SwiftUI

/// Cửa sổ Settings: sidebar 5 tab. Phase 0 nội dung tab còn rỗng,
/// sẽ thay bằng TypingPage/MacroPage/... ở phase sau.
struct SettingsRootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: Binding(
                get: { state.selectedPage },
                set: { if let v = $0 { state.selectedPage = v } }
            )) { page in
                Label(page.title, systemImage: page.systemImage)
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(180)
        } detail: {
            placeholder(for: state.selectedPage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        }
    }

    @ViewBuilder
    private func placeholder(for page: SettingsPage) -> some View {
        VStack(spacing: 8) {
            Image(systemName: page.systemImage).font(.largeTitle)
            Text(page.title).font(.title2)
            Text("(sẽ hoàn thiện ở phase sau)").foregroundStyle(.secondary)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/App/Views/SettingsRootView.swift
git commit -m "feat: add SettingsRootView skeleton (5-tab sidebar)"
```

---

### Task 9: DkeyApp entry point + build verify

**Files:**
- Create: `Sources/App/DkeyApp.swift`

- [ ] **Step 1: Tạo `Sources/App/DkeyApp.swift`**

Create `Sources/App/DkeyApp.swift`:
```swift
import AppKit
import SwiftUI

@main
struct DkeyApp: App {
    @NSApplicationDelegateAdaptor(DkeyAppDelegate.self) private var appDelegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(state)
        } label: {
            MenuBarLabel()
                .environmentObject(state)
        }

        Window("dkey — Bộ gõ Tiếng Việt", id: "settings") {
            SettingsRootView()
                .environmentObject(state)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 520)
    }
}

/// Icon nằm cố định trên menu bar; cũng là nơi nhận yêu cầu mở Settings.
struct MenuBarLabel: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(nsImage: StatusIcon.image(vietnamese: state.isVietnamese, gray: state.grayIcon))
            .onReceive(NotificationCenter.default.publisher(for: .dkOpenSettingsWindow)) { _ in
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}

struct MenuContent: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Tiếng Việt  \(AppState.hotkeyDescription(state.switchKeyStatus))",
               isOn: $state.isVietnamese)

        Divider()

        Button("Cài đặt…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Divider()

        Button("Thoát dkey") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

final class DkeyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Phase 0: chưa khởi động engine/event-tap. Chỉ mở Settings lần đầu
        // để xác nhận app chạy.
        NotificationCenter.default.post(name: .dkOpenSettingsWindow, object: nil)
    }
}

extension Notification.Name {
    static let dkOpenSettingsWindow = Notification.Name("dkOpenSettingsWindow")
}
```

- [ ] **Step 2: Generate project**

Run:
```bash
xcodegen generate
```
Expected: `Created project at .../dkey.xcodeproj` (không lỗi).

- [ ] **Step 3: Build**

Run:
```bash
xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build build 2>&1 | tail -20
```
Expected: dòng cuối `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Smoke-launch app, xác nhận chạy rồi tắt**

Run:
```bash
open build/Build/Products/Debug/dkey.app
sleep 3
osascript -e 'tell application "dkey" to quit' 2>/dev/null || pkill -x dkey
```
Expected: icon "V" xuất hiện trên menu bar + cửa sổ Settings hiện ra với 5 tab trong sidebar (xác nhận bằng mắt). Nếu chạy headless, ít nhất `open` không báo lỗi.

- [ ] **Step 5: Commit**

```bash
git add Sources/App/DkeyApp.swift
git commit -m "feat: add DkeyApp entry point (MenuBarExtra + Settings window)"
```

---

### Task 10: Smoke test target

**Files:**
- Create: `Tests/SmokeTests/SmokeTests.swift`

- [ ] **Step 1: Viết test kiểm tra AppState defaults + hotkeyDescription**

Create `Tests/SmokeTests/SmokeTests.swift`:
```swift
import XCTest
@testable import dkey

@MainActor
final class SmokeTests: XCTestCase {
    func testAppStateDefaults() {
        let state = AppState.shared
        XCTAssertTrue(state.isVietnamese)
        XCTAssertEqual(state.selectedPage, .typing)
        XCTAssertEqual(state.switchKeyStatus, AppState.defaultSwitchKeyStatus)
    }

    func testHotkeyDescriptionAltZ() {
        // 0x7A000206: display char 'Z' (0x7A ở byte cao... thực tế 0x7A là keycode,
        // display char nằm ở >>24). Kiểm tra option-bit (0x200) tạo ra "⌥".
        let desc = AppState.hotkeyDescription(0x00000200)
        XCTAssertEqual(desc, "⌥")
    }

    func testSettingsPagesCount() {
        XCTAssertEqual(SettingsPage.allCases.count, 5)
    }
}
```

- [ ] **Step 2: Regenerate project (thêm test target) + chạy test**

Run:
```bash
xcodegen generate
xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build test 2>&1 | tail -25
```
Expected: `** TEST SUCCEEDED **` và 3 test pass.

Note: nếu scheme `dkey` không tự include test target, dùng `-scheme dkey` vẫn chạy được do XcodeGen tạo scheme gồm test. Nếu báo "scheme not found for testing", chạy `xcodebuild -list -project dkey.xcodeproj` để lấy tên scheme rồi thay vào.

- [ ] **Step 3: Commit**

```bash
git add Tests/SmokeTests/SmokeTests.swift
git commit -m "test: add smoke tests for AppState defaults and hotkey desc"
```

---

## Self-Review

**Spec coverage (Phase 0 phần của spec mục 2, 5, 8):**
- Cấu trúc thư mục `Sources/{App,Support}` + `Tests/` → Task 3, 6–10. ✅ (Engine/Platform để phase sau, đúng scope Phase 0.)
- LICENSE GPL v3 → Task 2. ✅
- Info.plist `LSUIElement`, region `vi`, attribution, bundle `com.datnm555.dkey` → Task 4. ✅
- Entitlements rỗng, sandbox off → Task 4. ✅
- MenuBarExtra + StatusIcon V/E → Task 7, 9. ✅
- Settings window 5 tab → Task 8. ✅
- XcodeGen, macOS 14, ad-hoc sign → Task 3. ✅

**Placeholder scan:** Mọi step có nội dung file/command cụ thể. UI tab nội dung rỗng là CHỦ ĐÍCH của Phase 0 (skeleton), không phải placeholder kế hoạch. ✅

**Type consistency:**
- `AppState.shared`, `isVietnamese`, `grayIcon`, `selectedPage`, `switchKeyStatus`, `hotkeyDescription(_:)`, `defaultSwitchKeyStatus` — dùng nhất quán Task 6/7/9/10. ✅
- `SettingsPage` enum + `.title`/`.systemImage` — Task 6, dùng ở Task 8. ✅
- `Notification.Name.dkOpenSettingsWindow` — định nghĩa + dùng trong Task 9. ✅
- `StatusIcon.image(vietnamese:gray:)` — Task 7, gọi ở Task 9. ✅

Không phát hiện sai lệch. Plan sẵn sàng thực thi.
