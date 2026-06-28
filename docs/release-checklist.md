# MemBar Release Checklist

This project can build a local ad-hoc signed DMG without external credentials.
Developer ID signing, notarization, GitHub release publishing, and Homebrew cask
distribution require account access and release assets outside the local repo.

## Local Validation

Run the full test suite with DerivedData outside the repository:

```bash
DEVELOPER_DIR="$HOME/Downloads/Xcode-beta.app/Contents/Developer" \
  xcodebuild test -project Monitor/Monitor.xcodeproj -scheme Monitor \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/membar-derived-data
```

Build a Release app without Xcode signing:

```bash
DEVELOPER_DIR="$HOME/Downloads/Xcode-beta.app/Contents/Developer" \
  xcodebuild -project Monitor/Monitor.xcodeproj -scheme Monitor \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/membar-release-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

## Local DMG

Create an ad-hoc signed DMG:

```bash
DEVELOPER_DIR="$HOME/Downloads/Xcode-beta.app/Contents/Developer" \
  ./scripts/build-dmg.sh
```

The script writes the full xcodebuild log to `/private/tmp/membar-build-*.log`.
If the build fails, use that log instead of relying on the shortened terminal
summary.

## Developer ID Signing

Requires:

- Apple Developer Program membership
- Developer ID Application certificate installed in the login keychain
- A stable bundle identifier and signing team decision

Release builds intended for public distribution should be signed with the
Developer ID identity instead of the script's ad-hoc signature.

## Notarization

Requires:

- Apple ID or App Store Connect API key with notarization access
- `xcrun notarytool` credentials configured locally or in CI

Submit the signed DMG or signed app archive, wait for notarization success, then
staple the ticket before publishing.

## GitHub Release

Requires repository release permissions and a version tag:

```bash
gh release create vX.Y.Z MemBar.dmg \
  --title 'MemBar vX.Y.Z' \
  --notes-file RELEASE_NOTES.md
```

Confirm the release asset downloads correctly before updating install docs.

## Homebrew Cask

Requires a published, versioned DMG URL and SHA-256 checksum:

```bash
shasum -a 256 MemBar.dmg
```

Update or submit the cask only after the GitHub release asset is final. Do not
reuse a tag with a different DMG checksum.
