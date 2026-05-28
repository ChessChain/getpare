#!/usr/bin/env bash
# Tools/sign-helper.sh — codesign the helper binary, then the app bundle.
# Order matters: nested binaries must be signed first. Hardened runtime on,
# secure-timestamp on, entitlements per Technical Design §7.

set -euo pipefail

ARCHIVE="${1:?Usage: sign-helper.sh <Pare.xcarchive>}"
TEAM_ID="${APPLE_TEAM_ID:?APPLE_TEAM_ID must be set}"
APP_PATH="$ARCHIVE/Products/Applications/Pare.app"
HELPER="$APP_PATH/Contents/Library/LaunchServices/com.clearpath.pare.helper"
APP_ENT="App/Sources/Pare.entitlements"
HELPER_ENT="Helper/Sources/Helper.entitlements"

# TODO: codesign the helper, then the framework bundles, then the .app.
echo "TODO: codesign --force --options runtime --timestamp --sign \"Developer ID Application: ClearPath Digital ($TEAM_ID)\" --entitlements \"$HELPER_ENT\" \"$HELPER\""
echo "TODO: codesign --force --options runtime --timestamp --sign \"Developer ID Application: ClearPath Digital ($TEAM_ID)\" --entitlements \"$APP_ENT\" \"$APP_PATH\""
