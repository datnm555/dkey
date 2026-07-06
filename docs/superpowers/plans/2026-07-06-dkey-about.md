# Giới thiệu (About) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the "Giới thiệu" Settings tab from a placeholder into a static About page (name, version, GPL v3 + OpenKey attribution, source links).

**Architecture:** A pure, testable `AppInfo` helper reads/formats the version from the bundle info dictionary; `AboutView` renders it; `SettingsRootView` routes the `.about` page to it. No engine, no persistence — a static view plus one URL-opening action.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit (macOS 14), XCTest, XcodeGen.

## Global Constraints

- Changes are `Sources/App/` only — no engine changes, `AppInfo` is pure Swift.
- Version comes from `Bundle.main` keys `CFBundleShortVersionString` + `CFBundleVersion`, displayed as `"<short> (<build>)"` (currently `"0.1.0 (1)"`); missing keys → fallback `"—"` (no crash).
- Attribution is **required** (GPL v3 port of OpenKey): the page must state "Giấy phép GPL v3 · Engine port từ OpenKey (Tuyen Mai)".
- Exact URLs: dkey → `https://github.com/datnm555/dkey`; OpenKey → `https://github.com/tuyenvm/OpenKey`.
- XcodeGen project: after creating any new file run `xcodegen generate` (files are listed explicitly in the generated pbxproj). `dkey.xcodeproj` is gitignored — never commit it.
- No regression: all prior tests (80 on `main`) stay green.
- Deployment target macOS 14.0, `SWIFT_VERSION` 5.9. Work on a feature branch (`feature/about`, already created), commit after each task.

---

## File Structure

- `Sources/App/AppInfo.swift` *(new)* — pure version read/format helper.
- `Sources/App/Views/AboutView.swift` *(new)* — the About tab view.
- `Sources/App/Views/SettingsRootView.swift` *(modify)* — route `.about` → `AboutView()`.
- `Tests/AppTests/AppInfoTests.swift` *(new)* — unit tests for `AppInfo.versionString(from:)`.

---

## Task 1: AppInfo version helper

**Files:**
- Create: `Sources/App/AppInfo.swift`
- Create: `Tests/AppTests/AppInfoTests.swift`

**Interfaces:**
- Produces: `enum AppInfo { static func versionString(from info: [String: Any]?) -> String; static var displayVersion: String }`. `versionString` returns `"<short> (<build>)"` or `"—"` when either key is missing/nil.

- [ ] **Step 1: Write the failing tests**

Create `Tests/AppTests/AppInfoTests.swift`:

```swift
import XCTest
@testable import dkey

final class AppInfoTests: XCTestCase {
    func testFormatsShortAndBuild() {
        let info: [String: Any] = ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1"]
        XCTAssertEqual(AppInfo.versionString(from: info), "0.1.0 (1)")
    }

    func testFallbackWhenNil() {
        XCTAssertEqual(AppInfo.versionString(from: nil), "—")
    }

    func testFallbackWhenMissingKeys() {
        XCTAssertEqual(AppInfo.versionString(from: ["CFBundleShortVersionString": "0.1.0"]), "—")
        XCTAssertEqual(AppInfo.versionString(from: [:]), "—")
    }
}
```

- [ ] **Step 2: Add the test file to the build and run to verify failure**

Run: `cd /Users/dat.nguyenmanh/Desktop/dat/my-git/dkey && xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -15`
Expected: compile failure — `AppInfo` is undefined.

- [ ] **Step 3: Implement `AppInfo`**

Create `Sources/App/AppInfo.swift`:

```swift
import Foundation

/// App identity/version, read from the bundle. `versionString(from:)` is pure so it can be tested.
enum AppInfo {
    static func versionString(from info: [String: Any]?) -> String {
        guard let info,
              let short = info["CFBundleShortVersionString"] as? String,
              let build = info["CFBundleVersion"] as? String
        else { return "—" }
        return "\(short) (\(build))"
    }

    static var displayVersion: String { versionString(from: Bundle.main.infoDictionary) }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -12`
Expected: `TEST SUCCEEDED` — 3 new `AppInfoTests` pass, all prior tests still pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/App/AppInfo.swift Tests/AppTests/AppInfoTests.swift
git commit -m "feat(app): add AppInfo version helper"
```
(Do NOT `git add dkey.xcodeproj` — it is gitignored.)

---

## Task 2: AboutView + tab wiring

**Files:**
- Create: `Sources/App/Views/AboutView.swift`
- Modify: `Sources/App/Views/SettingsRootView.swift`

**Interfaces:**
- Consumes: `AppInfo.displayVersion` (Task 1).
- Produces: `struct AboutView: View`.

- [ ] **Step 1: Build the About view**

Create `Sources/App/Views/AboutView.swift`:

```swift
import SwiftUI
import AppKit

struct AboutView: View {
    private let dkeyURL = URL(string: "https://github.com/datnm555/dkey")!
    private let openKeyURL = URL(string: "https://github.com/tuyenvm/OpenKey")!

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 64, height: 64)
            Text("dkey").font(.title).bold()
            Text("Bộ gõ Tiếng Việt cho macOS")
                .foregroundStyle(.secondary)
            Text("Phiên bản \(AppInfo.displayVersion)")
                .font(.callout).foregroundStyle(.secondary)

            Divider().frame(maxWidth: 260).padding(.vertical, 4)

            Text("Giấy phép GPL v3 · Engine port từ OpenKey (Tuyen Mai)")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Mã nguồn dkey") { NSWorkspace.shared.open(dkeyURL) }
                Button("OpenKey") { NSWorkspace.shared.open(openKeyURL) }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: 360)
    }
}
```

- [ ] **Step 2: Route the `.about` tab to it**

In `Sources/App/Views/SettingsRootView.swift`, add a `.about` case to the existing `switch` in the `detail:` closure (which currently routes `.typing` and falls through to the placeholder):

```swift
                switch state.selectedPage {
                case .typing: TypingSettingsView()
                case .about:  AboutView()
                default:      placeholder(for: state.selectedPage)
                }
```

- [ ] **Step 3: Regenerate + build**

Run: `xcodegen generate && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug build 2>&1 | tail -8`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Full test pass (regression gate)**

Run: `xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug test 2>&1 | tail -8`
Expected: `TEST SUCCEEDED` — no test added by this task; all prior tests (incl. Task 1's) green.

- [ ] **Step 5: Manual smoke (deferred to user)**

Open the built app → Cài đặt → Giới thiệu. Verify: icon + "dkey" + tagline + "Phiên bản 0.1.0 (1)" + the GPL/OpenKey line; clicking "Mã nguồn dkey" opens the dkey repo and "OpenKey" opens the OpenKey repo in the browser.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/Views/AboutView.swift Sources/App/Views/SettingsRootView.swift
git commit -m "feat(app): Giới thiệu (About) tab"
```

---

## Self-Review

**1. Spec coverage:**
- Icon + name + tagline + version from bundle → Task 2 view + Task 1 helper. ✅
- GPL v3 + OpenKey attribution line → Task 2. ✅
- Two source links (exact URLs) → Task 2. ✅
- `AppInfo.versionString(from:)` format + fallback → Task 1 tests. ✅
- Route `.about` (others keep placeholder) → Task 2 Step 2. ✅
- No engine change / no regression → both tasks' test steps. ✅

**2. Placeholder scan:** No TBD/TODO; every code step shows complete code; URLs, version keys, and the attribution string are literal.

**3. Type consistency:** `AppInfo.displayVersion` (Task 1) is the exact symbol `AboutView` consumes (Task 2). `AppInfo.versionString(from:)` signature matches its tests. `AboutView` matches the `SettingsRootView` switch case. ✅
