#!/usr/bin/env bash
# Tools/sign-appcast.sh — sign the Sparkle appcast.xml with our EdDSA key.

set -euo pipefail

DIR="${1:?Usage: sign-appcast.sh <dist/>}"
: "${SPARKLE_EDDSA_KEY:?}"

# TODO: install Sparkle's sign_update tool on the runner and call it here.
# sign_update "$DIR"/Pare-*.dmg "$SPARKLE_EDDSA_KEY"
echo "TODO: invoke Sparkle sign_update over assets in $DIR"
