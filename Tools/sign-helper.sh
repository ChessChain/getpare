#!/usr/bin/env bash
# Tools/sign-helper.sh — codesign the helper binary, then the app bundle.
# Order matters: nested binaries must be signed first. Hardened runtime on,
# secure-timestamp on, entitlements per Technical Design §7.

set -euo pipefail

ARCHIVE="${1:?Usage: sign-helper.sh <Pare.xcarchive>}"
TEAM_ID="${APPLE_TEAM_ID:?APPLE_TEAM_ID must be set}"
IDENTITY="Developer ID Application: ClearPath Digital ($TEAM_ID)"

APP_PATH="$ARCHIVE/Products/Applications/Pare.app"
HELPER_BIN="$APP_PATH/Contents/MacOS/com.clearpath.pare.helper"
HELPER_PLIST="$APP_PATH/Contents/Library/LaunchDaemons/com.clearpath.pare.helper.plist"

APP_ENT="App/Pare.entitlements"
HELPER_ENT="Helper/Helper.entitlements"

for f in "$HELPER_BIN" "$HELPER_PLIST" "$APP_ENT" "$HELPER_ENT"; do
    if [ ! -e "$f" ]; then
        echo "missing required artefact: $f" >&2
        exit 1
    fi
done

echo "Signing helper binary…"
codesign --force --options runtime --timestamp \
    --sign "$IDENTITY" \
    --entitlements "$HELPER_ENT" \
    "$HELPER_BIN"

echo "Signing app bundle…"
codesign --force --options runtime --timestamp \
    --sign "$IDENTITY" \
    --entitlements "$APP_ENT" \
    "$APP_PATH"

echo "Verifying…"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign --display --entitlements - "$HELPER_BIN" >/dev/null
codesign --display --entitlements - "$APP_PATH" >/dev/null

echo "Done."
