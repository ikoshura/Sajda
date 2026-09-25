# Sajda Release Guide

This guide separates local source builds from production distribution. The GitHub issue reports show that quarantine removal or ad-hoc signing can sometimes get an app open on one machine, but public releases should be Developer ID signed and notarized.

## Local Source Build

Requirements:

- macOS Sonoma 14.0 or newer
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

## Ad-hoc Release (no Developer ID)

When a Developer ID certificate is not available, the release can still be built
**ad-hoc signed** — which is what allows the app to launch on Apple Silicon at all.
Sajda 4.0.0 shipped this way. Treat it as a documented fallback, not the preferred
path: the release body must carry the Gatekeeper instructions below.

```sh
# Archive without signing, and check the metadata that goes into the bundle
xcodebuild -project Sajda.xcodeproj -scheme Sajda -configuration Release \
  -archivePath build/Sajda.xcarchive clean archive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
plutil -p build/Sajda.xcarchive/Products/Applications/Sajda.app/Contents/Info.plist \
  | grep -E 'CFBundleShortVersionString|CFBundleVersion|LSMinimumSystemVersion'

# Ad-hoc sign the archived app (no nested code, so no --deep and no entitlements work)
rm -rf build/export-adhoc && mkdir -p build/export-adhoc
cp -R build/Sajda.xcarchive/Products/Applications/Sajda.app build/export-adhoc/
codesign --force --sign - build/export-adhoc/Sajda.app
codesign -dv build/export-adhoc/Sajda.app 2>&1 | grep -E 'Signature|Identifier='

# Package the DMG: app + /Applications symlink, then verify the image
rm -rf build/dmg-stage && mkdir build/dmg-stage
ln -s /Applications build/dmg-stage/Applications
cp -R build/export-adhoc/Sajda.app build/dmg-stage/
hdiutil create -volname Sajda -srcfolder build/dmg-stage -ov -format UDZO build/Sajda-X.Y.Z.dmg
hdiutil verify build/Sajda-X.Y.Z.dmg
shasum -a 256 build/Sajda-X.Y.Z.dmg
```

Every ad-hoc release body must say, in plain words:

- The build is ad-hoc signed and not notarized, so macOS warns on first launch.
- First launch: right-click the app → **Open** → **Open**.
- If that dialog has no *Open* button: `xattr -dr com.apple.quarantine /Applications/Sajda.app`.
- The warning goes away once a notarized build is published.

## Notes

- Prefer Developer ID signing and notarization. If the certificate is unavailable, an
  ad-hoc build may be published as a documented fallback (see "Ad-hoc Release" above) —
  never as the preferred path, and always with the Gatekeeper instructions above.

- Do not publish ad-hoc signed builds as production releases.
- Do not ask normal users to run `xattr` or self-sign the app as the primary install path.
- Keep `NSLocationUsageDescription` in the shipped app `Info.plist`; macOS requires a location purpose string.
- Keep package dependencies pinned so release rebuilds are reproducible.
