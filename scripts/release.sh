#!/usr/bin/env bash
#
# Sajda release: archive -> Developer ID sign -> notarize -> staple -> DMG ->
# notarize -> staple -> appcast -> verify.
#
# Usage:
#   scripts/release.sh 4.4.15
#
# Prerequisites (one-time):
#   - "Developer ID Application" certificate in the login keychain
#   - notarytool credentials stored under $NOTARY_PROFILE:
#       xcrun notarytool store-credentials notarytool-sajda \
#         --apple-id <you@example.com> --team-id JSYLVAZ935
#   - Sparkle's EdDSA private key in the keychain (created by `generate_keys`)
#
# Everything is non-interactive apart from the one-off keychain prompts macOS
# shows the first time codesign / notarytool touch a stored secret.

set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version, e.g. 4.4.15>}"
TAG="v${VERSION}"

TEAM_ID="JSYLVAZ935"
SIGN_IDENTITY="Developer ID Application"
NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool-sajda}"
REPO_SLUG="ikoshura/Sajda"
DOWNLOAD_PREFIX="https://github.com/${REPO_SLUG}/releases/download/${TAG}/"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/Sajda.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
APP_PATH="${EXPORT_DIR}/Sajda.app"
DMG_NAME="Sajda-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
APPCAST_SRC="${BUILD_DIR}/appcast-src"

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

# Apple's secure-timestamp service (timestamp.apple.com) is flaky on this
# network: codesign resolves it over IPv6, which resets the connection roughly
# half the time (IPv4 is fine). That surfaces as
# "The timestamp service is not available" and, during export, Xcode has to
# timestamp ~6 Sparkle helpers in one pass — so a whole export only lands
# perhaps 1 in 10 attempts. Retry hard rather than lose a release to a bad
# TCP handshake. See docs/RELEASE.md ("Timestamp service flakiness").
# Usage: retry <attempts> <delay-seconds> <command...>
retry() {
  local attempts="$1" delay="$2" n=1
  shift 2
  until "$@"; do
    if [ "$n" -ge "$attempts" ]; then
      printf 'error: %s failed after %d attempts\n' "$*" "$n" >&2
      return 1
    fi
    printf '   ... attempt %d/%d failed, retrying in %ds\n' "$n" "$attempts" "$delay" >&2
    sleep "$delay"
    n=$((n + 1))
  done
}

# ---------------------------------------------------------------- sanity ----
step "Checking prerequisites"

grep -q "MARKETING_VERSION = ${VERSION};" Sajda.xcodeproj/project.pbxproj \
  || { echo "error: MARKETING_VERSION is not ${VERSION} in Sajda.xcodeproj"; exit 1; }

security find-identity -v -p codesigning | grep -q "${SIGN_IDENTITY}: " \
  || { echo "error: no '${SIGN_IDENTITY}' certificate in the keychain"; exit 1; }

# Exact certificate name ("Developer ID Application: Name (TEAM)"), so signing
# does not depend on there being exactly one such identity in the keychain.
SIGN_ID_FULL="$(security find-identity -v -p codesigning \
  | sed -n 's/.*"\(Developer ID Application[^"]*\)".*/\1/p' | head -n 1)"
[ -n "$SIGN_ID_FULL" ] || { echo "error: could not read the '${SIGN_IDENTITY}' identity name"; exit 1; }

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || { echo "error: notarytool profile '${NOTARY_PROFILE}' is missing."; \
       echo "       xcrun notarytool store-credentials ${NOTARY_PROFILE} --apple-id <id> --team-id ${TEAM_ID}"; exit 1; }

SPARKLE_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*artifacts/sparkle/Sparkle/bin/generate_appcast' 2>/dev/null | head -n 1)"
[ -n "$SPARKLE_BIN" ] || { echo "error: Sparkle tools not found; build the project once so SPM fetches Sparkle"; exit 1; }
SPARKLE_BIN="$(dirname "$SPARKLE_BIN")"
echo "Sparkle tools: $SPARKLE_BIN"

# --------------------------------------------------------------- archive ----
step "Archiving and signing (${SIGN_IDENTITY})"
# Archive/export clean up after themselves so a retry starts from scratch.
do_archive() {
  rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
  xcodebuild -project Sajda.xcodeproj -scheme Sajda -configuration Release \
    -archivePath "$ARCHIVE_PATH" clean archive
}
retry 3 10 do_archive

cat > "${BUILD_DIR}/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
</dict>
</plist>
PLIST

step "Exporting the archive"
do_export() {
  rm -rf "$EXPORT_DIR"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist"
}
retry 50 5 do_export

# ------------------------------------------------------------ notarize app ---
step "Notarizing the app"
do_notarize_app() {
  rm -f "${BUILD_DIR}/Sajda-notarize.zip"
  ditto -c -k --keepParent "$APP_PATH" "${BUILD_DIR}/Sajda-notarize.zip"
  xcrun notarytool submit "${BUILD_DIR}/Sajda-notarize.zip" \
    --keychain-profile "$NOTARY_PROFILE" --wait
}
retry 3 15 do_notarize_app
retry 3 10 xcrun stapler staple "$APP_PATH"
rm -f "${BUILD_DIR}/Sajda-notarize.zip"

# ------------------------------------------------------------------- dmg ----
step "Building the DMG"
rm -rf "${BUILD_DIR}/dmg-stage" "$DMG_PATH"
mkdir -p "${BUILD_DIR}/dmg-stage"
ln -s /Applications "${BUILD_DIR}/dmg-stage/Applications"
cp -R "$APP_PATH" "${BUILD_DIR}/dmg-stage/"
hdiutil create -volname Sajda -srcfolder "${BUILD_DIR}/dmg-stage" \
  -ov -format UDZO "$DMG_PATH" >/dev/null
hdiutil verify "$DMG_PATH" >/dev/null

# The DMG must be signed in its own right: Gatekeeper assesses it before the
# app inside it, and an unsigned DMG is refused with "source=no usable
# signature" even when its contents are notarized. Skip this and the released
# download prompts on first open.
step "Signing the DMG"
do_sign_dmg() {
  codesign --force --timestamp -s "$SIGN_ID_FULL" "$DMG_PATH"
}
retry 10 5 do_sign_dmg
codesign --verify --verbose=2 "$DMG_PATH"

step "Notarizing the DMG"
do_notarize_dmg() {
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
}
retry 3 15 do_notarize_dmg
retry 3 10 xcrun stapler staple "$DMG_PATH"

# --------------------------------------------------------------- appcast ----
step "Generating the appcast"
rm -rf "$APPCAST_SRC"
mkdir -p "$APPCAST_SRC"
cp "$DMG_PATH" "$APPCAST_SRC/"

# Optional release notes: build/release-notes/Sajda-<version>.md is embedded
# into the appcast item, so the update dialog shows what changed.
NOTES="${BUILD_DIR}/release-notes/${DMG_NAME%.dmg}.md"
EMBED_NOTES=""
if [ -f "$NOTES" ]; then
  cp "$NOTES" "$APPCAST_SRC/${DMG_NAME%.dmg}.md"
  EMBED_NOTES="--embed-release-notes"
fi

# shellcheck disable=SC2086
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  $EMBED_NOTES \
  --maximum-versions 3 \
  "$APPCAST_SRC"

cp "${APPCAST_SRC}/appcast.xml" website/static/appcast.xml
echo "appcast -> website/static/appcast.xml"
# Rebuild the site so the published copy under docs/ (GitHub Pages) picks it
# up — zola build cleans output_dir, so this is also what re-emits everything
# in website/static/ (appcast, geocode.json, RELEASE.md, .nojekyll).
if command -v zola > /dev/null 2>&1; then
  (cd website && zola build)
  echo "site -> docs/ (zola build)"
else
  echo "warning: zola not installed; docs/ not regenerated" >&2
fi

# -------------------------------------------------------------- verify ------
step "Verifying with Gatekeeper"
spctl -a -vvv --type execute "$APP_PATH"
# A disk image needs an explicit assessment context; without it spctl answers
# "Insufficient Context" even for a correctly signed and stapled DMG.
spctl -a -vvv --type open --context context:primary-signature "$DMG_PATH"
xcrun stapler validate "$APP_PATH"
xcrun stapler validate "$DMG_PATH"
shasum -a 256 "$DMG_PATH"

step "Done"
cat <<EOF
Version:   $VERSION ($TAG)
DMG:       $DMG_PATH
Appcast:   docs/appcast.xml  ->  https://ikoshura.github.io/Sajda/appcast.xml

Remaining, manual:
  git add -A && git commit -m "release: $VERSION"
  git tag $TAG && git push origin main --tags
  gh release create $TAG --title "Sajda $VERSION" --notes-file <notes> "$DMG_PATH"
EOF