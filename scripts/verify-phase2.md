# Phase 2 — Manual Smoke Verification

Build & launch:
    xcodegen generate && rm -rf build && xcodebuild -project dkey.xcodeproj -scheme dkey -configuration Debug -derivedDataPath build build
    open build/Build/Products/Debug/dkey.app

Grant Accessibility when prompted (System Settings ▸ Privacy & Security ▸ Accessibility ▸ enable dkey), then re-launch if needed.

Check each item:
- [ ] Menu-bar shows the "V" icon.
- [ ] In TextEdit, type `tieesng vieejt` → renders `tiếng việt`.
- [ ] Type `dduongwf` → `đường` (đ + horn + huyền).
- [ ] Type `hoaf` → `hòa`; `quoocs` → `quốc`.
- [ ] Press ⌥Z → icon flips to "E"; typing `tieesng` now stays `tieesng` (raw).
- [ ] Press ⌥Z again → "V"; the menu "Tiếng Việt" toggle also flips the icon.
- [ ] ⌘C / ⌘A / arrow keys behave normally (not transformed or eaten).
- [ ] Sleep the machine (`pmset sleepnow` or close lid) → wake → typing still produces Vietnamese (tap re-armed).
- [ ] Hold ~8 keys at once to trip the tap timeout, release → typing still works (auto-recovery).

If any item fails, note it; the failing layer is EventTap (recovery/self-filter), KeySynthesizer (wrong chars/backspaces), or the InputController mapping.
