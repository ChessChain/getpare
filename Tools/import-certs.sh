#!/usr/bin/env bash
# Tools/import-certs.sh — import Developer ID signing certs into a temporary
# keychain inside the CI runner. Required env: DEV_ID_CERT_BASE64, DEV_ID_CERT_PASSWORD.

set -euo pipefail

KEYCHAIN="pare-ci.keychain-db"
KEYCHAIN_PWD="$(uuidgen)"
P12_PATH="$(mktemp -t pare-cert).p12"

echo "$DEV_ID_CERT_BASE64" | base64 --decode > "$P12_PATH"

security create-keychain -p "$KEYCHAIN_PWD" "$KEYCHAIN"
security default-keychain -s "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PWD" "$KEYCHAIN"
security set-keychain-settings -lut 3600 "$KEYCHAIN"
security import "$P12_PATH" -k "$KEYCHAIN" -P "$DEV_ID_CERT_PASSWORD" \
    -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PWD" "$KEYCHAIN"

rm -f "$P12_PATH"
echo "Signing certs imported into temporary keychain: $KEYCHAIN"
