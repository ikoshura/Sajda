# Sajda Release Guide

Sajda ships as a **Developer ID signed, Apple-notarized DMG**, and the same build feeds Sparkle's appcast so existing installs update themselves.

The whole pipeline is automated in [`scripts/release.sh`](../scripts/release.sh). The sections below document what that script does, for when it needs to change or be run step by step by hand.

## Automated Release

```sh
scripts/release.sh 4.4.15
```

It archives, exports with Developer ID signing, notarizes and staples both the app and the DMG, regenerates `docs/appcast.xml` (which GitHub Pages serves at `https://ikoshura.github.io/Sajda/appcast.xml`), and verifies the result with Gatekeeper. It then prints the git/`gh` commands to publish.

One-time prerequisites:

```sh
# Developer ID Application certificate in the login keychain (Xcode > Settings > Accounts)
xcrun notarytool store-credentials notarytool-sajda \
  --apple-id <your-apple-id> --team-id JSYLVAZ935

# Sparkle's EdDSA key pair — the private half lives in the keychain, the public
# half is already in Sajda/Info.plist as SUPublicEDKey. Only run this once:
# (tools are under DerivedData/.../artifacts/sparkle/Sparkle/bin)
./generate_keys
```

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

## Sparkle Appcast

`scripts/release.sh` regenerates the feed from the new DMG:

```sh
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "https://github.com/ikoshura/Sajda/releases/download/v4.4.15/" \
  --embed-release-notes \
  --maximum-versions 3 \
  build/appcast-src
cp build/appcast-src/appcast.xml docs/appcast.xml
```

Notes:

- `docs/appcast.xml` is committed and served by GitHub Pages — that URL is what
  `SUFeedURL` in `Sajda/Info.plist` points at. **The appcast must be published
  before or with the DMG**, or clients will 404 the update.
- `generate_appcast` signs every item with the EdDSA key in the keychain. The
  matching public key is `SUPublicEDKey` in `Sajda/Info.plist`; Sparkle refuses
  an item that does not verify against it.
- Release notes come from `build/release-notes/Sajda-<version>.md`, which the
  script embeds into the item (so the update dialog can show what changed).
- The `Sparkle` acknowledgement in the About page and the README must stay in
  step with the version actually bundled.

## Timestamp Service Flakiness

`codesign --timestamp` talks to `http://timestamp.apple.com/ts01`. On some
networks that host only behaves over IPv4 — but `codesign` resolves it over
IPv6, and the IPv6 path resets the connection roughly half the time. The
symptom is always the same and always looks like a signing bug:

```
codesign: <path>: The timestamp service is not available.
error: exportArchive codesign command failed (...)
** EXPORT FAILED **
```

It is not a signing bug. It only means a TCP handshake to Apple's timestamp
server got reset, and it is worth knowing that during `exportArchive` Xcode has
to timestamp every Sparkle helper (`Autoupdate`, `Updater.app`, `Installer.xpc`,
`Downloader.xpc`, …) in one pass — so one reset anywhere fails the whole export,
even though the archive itself signed fine moments earlier.

Two ways out:

1. **Retry** — `scripts/release.sh` wraps archive, export and both notarization
   steps in `retry` for exactly this reason, so a normal run rides it out.
2. **Fix it at the source** — pin the host to IPv4 so `codesign` never touches
   the broken path. One-off, needs an admin shell:

   ```sh
   echo "17.157.80.35 timestamp.apple.com" | sudo tee -a /etc/hosts
   ```

   Check it took effect with `dscacheutil -q host -a name timestamp.apple.com`
   (should print only the IPv4 address), and see `nslookup timestamp.apple.com`
   again if Apple ever rotates the address.

A quick way to see whether you are being hit by this:

```sh
# IPv4 vs IPv6 reliability for one timestamp request
openssl ts -query -data /etc/hosts -sha256 -cert -out /tmp/q.tsq
for flag in -4 -6; do
  curl $flag -sS -o /dev/null -w "$flag %{http_code}\n" \
    -H "Content-Type: application/timestamp-query" \
    --data-binary @/tmp/q.tsq --max-time 10 http://timestamp.apple.com/ts01
done
```

If `-4` returns `200` and `-6` errors, use fix 2.

## Notes

- Every release must be Developer ID signed and notarized: the app is sandboxed
  and Sparkle installs updates through its Installer XPC service, which requires
  a real signature and a team identifier.
- Keep `SUPublicEDKey` in `Sajda/Info.plist` in agreement with the EdDSA key in
  the login keychain. Losing the private key means existing installs can never
  be updated again.
- Keep the `com.apple.security.temporary-exception.mach-lookup.global-name`
  entries in `Sajda.entitlements` (`$(PRODUCT_BUNDLE_IDENTIFIER)-spks`/`-spki`);
  without them a sandboxed app downloads updates it can never install.
- Keep `NSLocationUsageDescription` in the shipped app `Info.plist`; macOS requires a location purpose string.
- Keep package dependencies pinned so release rebuilds are reproducible.
