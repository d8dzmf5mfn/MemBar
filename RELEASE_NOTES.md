# MemBar v1.1.0

Productization release focused on settings, metrics architecture, and release
diagnostics.

## Changes

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
