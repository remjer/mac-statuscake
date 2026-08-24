#!/bin/bash
#
# Packages StatusCakeApp as a real .app bundle. `swift build`/`swift run`
# alone produce a bare Mach-O executable, which was fine through phase 4 but
# is not enough for two things this app now needs: UNUserNotificationCenter
# (which crashes without a bundle identifier -- see NotificationDelivery.swift)
# and a login item that survives being anywhere other than a build folder.
#
# Signing: no Developer ID Application certificate exists for this project
# yet (only an "Apple Development" one, which isn't meant for distributing
# to other machines), so this defaults to ad-hoc signing -- fine for running
# on this Mac. Set SIGN_IDENTITY to a Developer ID Application identity, and
# NOTARIZE_PROFILE to a `notarytool store-credentials` profile name, once
# those exist and this needs to run on someone else's Mac.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="StatusCake"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/.build/$APP_NAME.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

echo "Building release binary..."
swift build -c release --product StatusCakeApp --package-path "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/StatusCakeApp" "$APP_DIR/Contents/MacOS/StatusCakeApp"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
if [ -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

echo "Signing with identity: $SIGN_IDENTITY"
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_DIR"
codesign --verify --verbose "$APP_DIR"

echo
echo "Built $APP_DIR"
echo "Move it to /Applications for launch-at-login to keep working after this build folder changes:"
echo "  cp -R \"$APP_DIR\" /Applications/"

if [ -n "${NOTARIZE_PROFILE:-}" ]; then
    echo
    echo "Notarizing with profile: $NOTARIZE_PROFILE"
    ZIP_PATH="$ROOT_DIR/.build/$APP_NAME.zip"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARIZE_PROFILE" --wait
    xcrun stapler staple "$APP_DIR"
fi
