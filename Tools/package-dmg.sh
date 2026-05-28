#!/usr/bin/env bash
# Tools/package-dmg.sh — wrap the signed .app into a styled DMG.

set -euo pipefail

APP="${1:?Usage: package-dmg.sh <Pare.app> <out.dmg>}"
OUT="${2:?Usage: package-dmg.sh <Pare.app> <out.dmg>}"
STAGING="$(mktemp -d)"

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Pare" -srcfolder "$STAGING" \
    -ov -format UDZO "$OUT"

rm -rf "$STAGING"
echo "DMG created: $OUT"
