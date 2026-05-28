#!/bin/bash
set -e

VERSION="${1:-1.0.0}"
SWIFT=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift

# ── Configuration (update these before first release) ────────────
IDENTITY="${PARE_SIGN_IDENTITY:-}"  # e.g. "Developer ID Application: Marcel Diboh (TEAMID)"
APPLE_ID="${PARE_APPLE_ID:-}"       # your Apple ID email
APP_PASSWORD="${PARE_APP_PASSWORD:-}" # app-specific password from appleid.apple.com
TEAM_ID="${PARE_TEAM_ID:-}"         # your Apple Team ID
# ─────────────────────────────────────────────────────────────────

APP="Pare.app"
DMG="Pare-${VERSION}.dmg"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       Pare Release Builder v1.0          ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Version:  $VERSION                         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Step 1: Build ────────────────────────────────────────────────
echo "→ Building release binary..."
$SWIFT build -c release 2>&1 | tail -3

if [ ! -f ".build/release/Pare" ]; then
    echo "✗ Build failed — no binary at .build/release/Pare"
    exit 1
fi
echo "✓ Build complete"

# ── Step 2: Create .app bundle ───────────────────────────────────
echo "→ Creating app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/Pare "$APP/Contents/MacOS/Pare"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Pare</string>
    <key>CFBundleIdentifier</key>
    <string>com.clearpath.pare</string>
    <key>CFBundleName</key>
    <string>Pare</string>
    <key>CFBundleDisplayName</key>
    <string>Pare</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>Pare needs access to scan and clean system files.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

# Copy icon if available
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
elif [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

echo "✓ App bundle created"

# ── Step 3: Code Sign ────────────────────────────────────────────
if [ -n "$IDENTITY" ]; then
    echo "→ Signing with: $IDENTITY"
    codesign --force --deep --options runtime \
        --sign "$IDENTITY" \
        --timestamp \
        "$APP"
    codesign -dv "$APP" 2>&1 | grep "Authority"
    echo "✓ Code signed"
else
    echo "⚠ No signing identity set — using ad-hoc signature"
    echo "  Set PARE_SIGN_IDENTITY env var for production builds"
    codesign --force --deep --sign - "$APP"
fi

# ── Step 4: Create DMG ──────────────────────────────────────────
echo "→ Creating DMG..."
rm -rf dmg-staging "$DMG"
mkdir -p dmg-staging
cp -R "$APP" dmg-staging/
ln -s /Applications dmg-staging/Applications

hdiutil create -volname "Pare $VERSION" \
    -srcfolder dmg-staging \
    -ov -format UDZO \
    "$DMG" 2>&1 | tail -1

rm -rf dmg-staging

if [ -n "$IDENTITY" ]; then
    codesign --sign "$IDENTITY" --timestamp "$DMG"
fi

echo "✓ DMG created: $DMG ($(du -h "$DMG" | cut -f1))"

# ── Step 5: Notarize (if credentials available) ─────────────────
if [ -n "$APPLE_ID" ] && [ -n "$APP_PASSWORD" ] && [ -n "$TEAM_ID" ]; then
    echo "→ Submitting for notarization..."
    xcrun notarytool submit "$DMG" \
        --apple-id "$APPLE_ID" \
        --password "$APP_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait

    echo "→ Stapling notarization ticket..."
    xcrun stapler staple "$DMG"
    echo "✓ Notarized and stapled"
else
    echo "⚠ Skipping notarization — set PARE_APPLE_ID, PARE_APP_PASSWORD, PARE_TEAM_ID"
fi

# ── Step 6: GitHub Release ───────────────────────────────────────
echo ""
read -p "Create GitHub release v${VERSION}? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    gh release create "v${VERSION}" "$DMG" \
        --title "Pare v${VERSION}" \
        --notes "$(cat <<EOF
## Pare v${VERSION}

### Download
- **[Pare-${VERSION}.dmg](https://github.com/ChessChain/getpare/releases/download/v${VERSION}/Pare-${VERSION}.dmg)** — macOS 13+, Apple Silicon & Intel

### Install
1. Open the DMG
2. Drag Pare to Applications
3. Open Pare — works immediately (free tier)
4. Purchase a licence key at [getpare.lemonsqueezy.com](https://getpare.lemonsqueezy.com) for unlimited cleanup

### What's included
- 11 cleanup categories (System Junk, Developer, Downloads, Mail, Browser, and more)
- Space Lens visual disk browser
- 30-day Recovery Bin
- Insights & trends dashboard
- 100% on-device — nothing leaves your Mac
EOF
)"
    echo "✓ GitHub release created"
    echo "  https://github.com/ChessChain/getpare/releases/tag/v${VERSION}"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║            Release Summary               ║"
echo "╠══════════════════════════════════════════╣"
echo "  Version:  $VERSION"
echo "  Binary:   $APP/Contents/MacOS/Pare"
echo "  Bundle:   $APP"
echo "  DMG:      $DMG ($(du -h "$DMG" | cut -f1))"
echo "  Signed:   $([ -n "$IDENTITY" ] && echo "Yes" || echo "Ad-hoc")"
echo "  Notarized: $([ -n "$APPLE_ID" ] && echo "Yes" || echo "No")"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Upload $DMG to LemonSqueezy product files"
echo "  2. Update website download link"
echo "  3. Test on a clean Mac"
