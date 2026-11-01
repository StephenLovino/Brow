#!/usr/bin/env bash
# Builds Brow.app, signs it with a Developer ID, notarizes and staples it, then wraps it in a
# signed, notarized and stapled dist/Brow.dmg.
#
#   Packaging/release.sh                 # full release into dist/
#   SKIP_NOTARIZE=1 Packaging/release.sh # signed build only
#
# One-time setup (stores your app-specific password in the keychain):
#   xcrun notarytool store-credentials brow-notary --apple-id <you@example.com> --team-id <TEAMID>
#
# Environment:
#   VERSION         marketing version (default 1.0.0)
#   BUILD           build number (default: commit count)
#   SIGN_IDENTITY   codesign identity name or SHA-1 (default: first "Developer ID Application" identity)
#   NOTARY_PROFILE  notarytool keychain profile (default brow-notary)
#   APPLE_ID_USER, APPLE_APP_PASSWORD
#                   Apple ID and app-specific password; used instead of the profile when both are set.
#                   The team ID is read from the signed app.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-brow-notary}"
DIST="dist"
APP="$DIST/Brow.app"
# The zip is only the upload format for notarizing the app; the DMG is what ships.
ZIP="$DIST/Brow.zip"
DMG="$DIST/Brow.dmg"

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    # Use the SHA-1 so duplicate certificates with the same name don't make codesign ambiguous.
    SIGN_IDENTITY="$(security find-identity -v -p codesigning \
        | awk '/Developer ID Application/ { print $2; exit }')"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "error: no Developer ID Application identity found; set SIGN_IDENTITY" >&2
    exit 1
fi

echo "==> Building universal release binary"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Brow"

echo "==> Assembling $APP"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Brow"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Packaging/Info.plist > "$APP/Contents/Info.plist"

ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
swift Packaging/make-icon.swift "$ICONSET/icon_512x512@2x.png" > /dev/null
for size in 16 32 128 256 512; do
    sips -z $size $size "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
    double=$((size * 2))
    [[ $size -lt 512 ]] && sips -z $double $double "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> Signing with $SIGN_IDENTITY"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
    echo "==> Skipping notarization; signed app at $APP"
    exit 0
fi

if [[ -n "${APPLE_ID_USER:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    TEAM_ID="$(codesign -dv "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
    echo "==> Notarizing (Apple ID from environment, team $TEAM_ID)"
    NOTARY_AUTH=(--apple-id "$APPLE_ID_USER" --password "$APPLE_APP_PASSWORD" --team-id "$TEAM_ID")
else
    echo "==> Notarizing (profile: $NOTARY_PROFILE)"
    NOTARY_AUTH=(--keychain-profile "$NOTARY_PROFILE")
fi
xcrun notarytool submit "$ZIP" "${NOTARY_AUTH[@]}" --wait

echo "==> Stapling the app"
xcrun stapler staple "$APP"
rm "$ZIP"
spctl --assess --type execute --verbose=2 "$APP"

echo "==> Building $DMG"
STAGING="$(mktemp -d)/Brow"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/Brow.app"
ln -s /Applications "$STAGING/Applications"
RW_DMG="$(mktemp -d)/Brow-rw.dmg"
hdiutil create -volname Brow -srcfolder "$STAGING" -fs HFS+ -format UDRW -ov "$RW_DMG" > /dev/null

# Lay out the Finder window: app on the left, Applications on the right, sunflower background.
# Needs Finder automation permission; if it's refused, the DMG still works, just unstyled.
MOUNT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | awk -F'\t' '/\/Volumes\// { print $NF }')"
osascript <<APPLESCRIPT || echo "warning: couldn't style the DMG window; continuing"
tell application "Finder"
    tell disk "$(basename "$MOUNT")"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 760, 480}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background color of viewOptions to {65535, 62965, 52428}
        set position of item "Brow.app" of container window to {150, 170}
        set position of item "Applications" of container window to {410, 170}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
sync
hdiutil detach "$MOUNT" -quiet
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG" > /dev/null

echo "==> Signing and notarizing $DMG"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
xcrun notarytool submit "$DMG" "${NOTARY_AUTH[@]}" --wait
xcrun stapler staple "$DMG"

spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
shasum -a 256 "$DMG"
echo "==> Done: $DMG"
