#!/usr/bin/env bash
# Tools/upload-release.sh — push signed assets + appcast to the release CDN.

set -euo pipefail

DIR="${1:?Usage: upload-release.sh <dist/>}"

# TODO: rsync / aws s3 cp / cloudflare R2 push, depending on chosen CDN.
echo "TODO: upload $DIR/* to releases.pare.app"
