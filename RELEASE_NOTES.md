# MemBar v1.0.2

Maintenance release focused on release quality and measurement correctness.

## Changes

- Removed the invalid `Caveat-Regular.ttf` resource that contained a GitHub HTML page instead of font data.
- Register only the valid bundled `RockSalt-Regular.ttf` font at launch.
- Hardened CPU tick delta calculations so counter rollback does not create synthetic CPU spikes.
- Expanded network throughput accounting to active non-loopback interfaces, covering VPN, bridge, and virtual interfaces instead of only `en*` / `ap*`.
- Added regression coverage for font resources, CPU counter rollback, and network interface filtering.
- Documented running command-line tests with DerivedData under `/private/tmp` to avoid workspace extended-attribute codesign failures.

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

This local release build is ad-hoc signed. If macOS shows an unidentified developer warning, right-click `MemBar.app` and choose Open.
