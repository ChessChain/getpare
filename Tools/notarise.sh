#!/usr/bin/env bash
# Tools/notarise.sh — submit the app to Apple's notary service and staple
# the resulting ticket. Supports --dry-run for the nightly workflow.

set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then DRY_RUN=1; shift; fi
APP="${1:?Usage: notarise.sh [--dry-run] <Pare.app|Pare.xcarchive>}"

: "${APPLE_ID:?}"
: "${APPLE_APP_PASSWORD:?}"
: "${APPLE_TEAM_ID:?}"

ZIP="$(mktemp -t pare-notary).zip"
ditto -c -k --keepParent "$APP" "$ZIP"

CMD=(xcrun notarytool submit "$ZIP" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait)

if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY RUN: would run: ${CMD[*]}"
else
    "${CMD[@]}"
    xcrun stapler staple "$APP"
fi

rm -f "$ZIP"
