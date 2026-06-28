# MemBar v1.1.2

Patch release focused on fixing Settings opening in the menu-bar-only app.

## Changes

- Fixed the **设置** button doing nothing in the popover.
- Fixed the right-click **Settings** item by routing it directly to the app delegate.
- Replaced the fragile SwiftUI Settings selector path with a reusable AppKit settings window.
- Added a visible **设置** button in the popover footer.
- Added **Settings** to the right-click menu bar menu.
- Added a real macOS Settings window for default menu-bar mode, network smoothing, and refresh interval.
- Introduced `PreferencesStore` so user preferences are shared by the app, monitor, and settings UI.
- Refactored metrics collection behind provider types and a `MetricsEngine`, keeping `SystemMonitor` focused on UI-facing state.
- Kept the existing popover and menu-bar rendering surface intact while allowing 1 s, 2 s, or 5 s refresh intervals.
- Added tests for preferences, metric providers, and metrics engine lifecycle behavior.
- Improved local DMG build diagnostics by writing the full xcodebuild log to `/private/tmp`.
- Added a release checklist covering local DMG builds, Developer ID signing, notarization, GitHub releases, and Homebrew cask requirements.

## Validation

- Full macOS test suite passes with:

```bash
DEVELOPER_DIR="$HOME/Downloads/Xcode-beta.app/Contents/Developer" \
  xcodebuild test -project Monitor/Monitor.xcodeproj -scheme Monitor \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/membar-derived-data
```

## Install

Download `MemBar.dmg` from this release, open it, and drag `MemBar.app` into Applications.

This release asset is ad-hoc signed. If macOS shows an unidentified developer warning, right-click `MemBar.app` and choose Open.
