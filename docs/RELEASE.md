# Sajda Release Guide

This guide separates local source builds from production distribution. The GitHub issue reports show that quarantine removal or ad-hoc signing can sometimes get an app open on one machine, but public releases should be Developer ID signed and notarized.

## Local Source Build

Requirements:

- macOS Ventura 13.3 or newer
- Xcode with the macOS SDK installed

Build without a Developer ID certificate:

```sh
xcodebuild \
  -project Sajda.xcodeproj \
  -scheme Sajda \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run the local build:

```sh
open build/DerivedData/Build/Products/Debug/Sajda.app
```

## Production Release Checklist

- Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Sajda target.
- Confirm About shows the bundle version from `CFBundleShortVersionString`.
- Build from a clean checkout.
- Sign with a valid Developer ID Application certificate.
- Enable Hardened Runtime.
- Keep the app sandbox entitlements intact.
- Notarize the app or final DMG.
- Staple the notarization ticket.
- Verify with Gatekeeper before publishing.

## Archive And Export

Create a release archive:

```sh
xcodebuild \
  -project Sajda.xcodeproj \
  -scheme Sajda \
  -configuration Release \
  -archivePath build/Sajda.xcarchive \
  clean archive
```

Export with Developer ID signing. Create `build/ExportOptions.plist` with your team ID:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>teamID</key>
  <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

Then export:

```sh
xcodebuild \
  -exportArchive \
  -archivePath build/Sajda.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist build/ExportOptions.plist
```

## Notarize

Create a zip for notarization:

```sh
ditto -c -k --keepParent build/export/Sajda.app build/Sajda.zip
```

Submit and wait:

```sh
xcrun notarytool submit build/Sajda.zip \
  --keychain-profile notarytool-sajda \
  --wait
```

Staple and verify:

```sh
xcrun stapler staple build/export/Sajda.app
spctl -a -vv --type execute build/export/Sajda.app
```

## DMG

Package after the app is stapled:

```sh
hdiutil create \
  -volname Sajda \
  -srcfolder build/export/Sajda.app \
  -ov \
  -format UDZO \
  build/Sajda.dmg
```

Notarize and staple the DMG too:

```sh
xcrun notarytool submit build/Sajda.dmg \
  --keychain-profile notarytool-sajda \
  --wait
xcrun stapler staple build/Sajda.dmg
spctl -a -vv --type open build/Sajda.dmg
```

## Notes

- Do not publish ad-hoc signed builds as production releases.
- Do not ask normal users to run `xattr` or self-sign the app as the primary install path.
- Keep `NSLocationUsageDescription` in the shipped app `Info.plist`; macOS requires a location purpose string.
- Keep package dependencies pinned so release rebuilds are reproducible.
