#!/usr/bin/env bash
# Tools/build-app-bundle.sh — wrap SPM build output into a .app bundle.
#
# Usage: Tools/build-app-bundle.sh [debug|release]   (default: debug)
#
# Produces dist/Pare.app structured for SMAppService:
#   Pare.app/
#     Contents/
#       Info.plist
#       MacOS/
#         Pare
#         com.clearpath.pare.helper
#       Library/LaunchDaemons/
#         com.clearpath.pare.helper.plist
#       Resources/
#         Assets.xcassets   (uncompiled — SPM doesn't run actool)
#         Localizable.strings
#
# The bundle is NOT signed. For dev use it's fine — notifications and
# bundle-coupled APIs work. For SMAppService.daemon.register to actually
# succeed, run Tools/sign-helper.sh once you have a real Apple Developer
# Team ID and a Developer ID Application certificate installed.

set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
BUILD_DIR=".build/arm64-apple-macosx/$CONFIG"
DIST="dist"
APP="$DIST/Pare.app"

if [ ! -x "$BUILD_DIR/Pare" ] || [ ! -x "$BUILD_DIR/ParePrivilegedHelper" ]; then
    echo "Missing build product under $BUILD_DIR" >&2
    if [ "$CONFIG" = "release" ]; then
        echo "Run: swift build --configuration release" >&2
    else
        echo "Run: swift build" >&2
    fi
    exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Library/LaunchDaemons"
mkdir -p "$APP/Contents/Resources"

# ── Binaries ─────────────────────────────────────────────────────────────
cp "$BUILD_DIR/Pare"                   "$APP/Contents/MacOS/Pare"
cp "$BUILD_DIR/ParePrivilegedHelper"   "$APP/Contents/MacOS/com.clearpath.pare.helper"

# ── Helper launchd plist ─────────────────────────────────────────────────
cp Helper/com.clearpath.pare.helper.plist \
    "$APP/Contents/Library/LaunchDaemons/com.clearpath.pare.helper.plist"

# ── Resources ────────────────────────────────────────────────────────────
# SPM emits an *.bundle directory next to the binary for `resources:
# [.process(...)]` outputs. We copy its contents straight into Resources/,
# then run `actool` on any Assets.xcassets so named-asset lookups (e.g.
# Image("AppIcon")) resolve at runtime via the compiled Assets.car.
if [ -d "$BUILD_DIR/Pare_AppLib.bundle" ]; then
    cp -R "$BUILD_DIR/Pare_AppLib.bundle"/. "$APP/Contents/Resources/"
fi

if [ -d "$APP/Contents/Resources/Assets.xcassets" ]; then
    # actool fails on an empty catalog (only Contents.json), so skip when
    # there are no imagesets/appiconsets/etc. yet.
    if find "$APP/Contents/Resources/Assets.xcassets" -mindepth 1 \
        \( -name "*.imageset" -o -name "*.appiconset" -o -name "*.symbolset" \
           -o -name "*.colorset" -o -name "*.dataset" \) -print -quit \
        | grep -q .; then
        xcrun actool "$APP/Contents/Resources/Assets.xcassets" \
            --compile "$APP/Contents/Resources" \
            --platform macosx \
            --minimum-deployment-target 13.0 \
            --app-icon AppIcon \
            --output-partial-info-plist "$APP/Contents/Resources/assets.plist" \
            >/dev/null
        rm -rf "$APP/Contents/Resources/Assets.xcassets"
        rm -f  "$APP/Contents/Resources/assets.plist"
    else
        # Empty catalog — drop it so it doesn't ship as dead weight.
        rm -rf "$APP/Contents/Resources/Assets.xcassets"
    fi
fi

# ── Info.plist ───────────────────────────────────────────────────────────
# Bundle identifier MUST match `AssociatedBundleIdentifiers` in
# `Helper/com.clearpath.pare.helper.plist` so macOS groups them as one
# Login Items entry.
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Pare</string>
    <key>CFBundleIdentifier</key>
    <string>com.clearpath.pare</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Pare</string>
    <key>CFBundleDisplayName</key>
    <string>Pare</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 ClearPath Digital. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
PLIST

echo "Bundle ready: $APP"
echo "  open $APP                                  # launch it"
echo "  codesign -dvv $APP                          # verify signing (will say 'not signed')"
echo "  APPLE_TEAM_ID=<id> Tools/sign-helper.sh ... # sign for SMAppService"
