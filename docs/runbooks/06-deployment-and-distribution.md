# Pare — Deployment & Distribution Runbook

## Overview

This runbook covers three distribution paths for Pare:

1. **Direct download** (from your website) — users buy a licence key via LemonSqueezy, download the DMG, install, and activate
2. **Mac App Store** — Apple handles distribution, updates, and payments
3. **Homebrew Cask** — for developer-oriented users

---

## Path 1: Direct Download (Recommended for v1.0)

This is the CleanMyMac model. You control the experience, keep ~95% of revenue, and ship faster.

### Prerequisites

| Item | Status | How to get it |
|------|--------|---------------|
| Apple Developer Account | Required | https://developer.apple.com ($99/year) |
| Developer ID Application certificate | Required | Xcode → Settings → Accounts → Manage Certificates |
| Developer ID Installer certificate | Required | Same as above |
| Notarization credentials | Required | App-specific password at https://appleid.apple.com |
| LemonSqueezy store | Done | https://getpare.lemonsqueezy.com |
| Domain for downloads | Recommended | e.g. pare.app or use LemonSqueezy hosting |

### Step 1: Build a Release Binary

```bash
# From the project root
cd /Users/marcelodiboh/Downloads/getpare

# Build release configuration
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift build -c release

# The binary is at:
# .build/release/Pare
```

### Step 2: Create the .app Bundle

```bash
# Create bundle structure
APP="Pare.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# Copy binary
cp .build/release/Pare "$APP/Contents/MacOS/Pare"

# Copy Info.plist
cat > "$APP/Contents/Info.plist" << 'EOF'
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
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
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
    <key>SUFeedURL</key>
    <string>https://getpare.lemonsqueezy.com/appcast.xml</string>
</dict>
</plist>
EOF

# Add PkgInfo
echo -n "APPL????" > "$APP/Contents/PkgInfo"
```

### Step 3: Create App Icon

```bash
# Create an .icns file from a 1024x1024 PNG
# You need a file called AppIcon.png (1024x1024)

mkdir -p AppIcon.iconset
sips -z 16 16     AppIcon.png --out AppIcon.iconset/icon_16x16.png
sips -z 32 32     AppIcon.png --out AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     AppIcon.png --out AppIcon.iconset/icon_32x32.png
sips -z 64 64     AppIcon.png --out AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   AppIcon.png --out AppIcon.iconset/icon_128x128.png
sips -z 256 256   AppIcon.png --out AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   AppIcon.png --out AppIcon.iconset/icon_256x256.png
sips -z 512 512   AppIcon.png --out AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   AppIcon.png --out AppIcon.iconset/icon_512x512.png
sips -z 1024 1024 AppIcon.png --out AppIcon.iconset/icon_512x512@2x.png
iconutil -c icns AppIcon.iconset -o Pare.app/Contents/Resources/AppIcon.icns
```

### Step 4: Code Sign

```bash
# Sign with your Developer ID
IDENTITY="Developer ID Application: Your Name (TEAMID)"

codesign --force --deep --options runtime \
  --sign "$IDENTITY" \
  --timestamp \
  Pare.app

# Verify
codesign -dv --verbose=4 Pare.app
spctl -a -vv Pare.app
```

### Step 5: Notarize

```bash
# Create a ZIP for notarization
ditto -c -k --keepParent Pare.app Pare.zip

# Submit for notarization
xcrun notarytool submit Pare.zip \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "TEAMID" \
  --wait

# Staple the notarization ticket
xcrun stapler staple Pare.app

# Verify
xcrun stapler validate Pare.app
```

### Step 6: Create DMG

```bash
# Create a DMG with a nice installer layout
mkdir -p dmg-contents
cp -R Pare.app dmg-contents/
ln -s /Applications dmg-contents/Applications

hdiutil create -volname "Pare" \
  -srcfolder dmg-contents \
  -ov -format UDZO \
  Pare-1.0.0.dmg

# Sign the DMG
codesign --sign "$IDENTITY" --timestamp Pare-1.0.0.dmg

# Notarize the DMG
xcrun notarytool submit Pare-1.0.0.dmg \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "TEAMID" \
  --wait

xcrun stapler staple Pare-1.0.0.dmg
```

### Step 7: Upload to LemonSqueezy

1. Go to https://app.lemonsqueezy.com/products
2. Edit your "Pare Premium" product
3. Under **Files**, upload `Pare-1.0.0.dmg`
4. Under **Confirmation modal**:
   - Heading: "Download Pare"
   - Body: "Click below to download. Your licence key has been emailed to you."
   - Button text: "Download Pare"
   - Button URL: (auto-links to the file)
5. Publish

### Step 8: Update Website

Update `website/index.html`:
- "Download for Mac" button → links to DMG download URL from LemonSqueezy
- Or host the DMG on GitHub Releases:

```bash
gh release create v1.0.0 Pare-1.0.0.dmg \
  --title "Pare v1.0.0" \
  --notes "Initial release"
```

### User Flow (Direct)

```
1. User visits getpare.lemonsqueezy.com or your website
2. Clicks "Download for Mac" → downloads Pare-1.0.0.dmg (free)
3. Opens DMG → drags Pare to Applications
4. Opens Pare → works immediately (free tier, 500 MB/mo)
5. When ready to upgrade → clicks "Get Premium" on website
6. LemonSqueezy checkout → pays $14.99
7. Receives licence key by email
8. Opens Pare → Settings → Licence → pastes key → Activate
9. Premium unlocked — unlimited cleanup
```

---

## Path 2: Mac App Store

### Additional Requirements

| Item | How to get it |
|------|---------------|
| App Store Connect account | https://appstoreconnect.apple.com |
| Mac App Store distribution certificate | Xcode → Settings → Accounts |
| Mac App Store installer certificate | Same |
| App sandbox entitlements | See below |
| Privacy descriptions in Info.plist | See below |
| App Store screenshots (5 required) | 2560x1600 for 13" Retina |
| App Store description, keywords | See below |

### Entitlements for App Store

Create `Pare.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.temporary-exception.files.absolute-path.read-only</key>
    <array>
        <string>/Applications/</string>
        <string>/Library/</string>
    </array>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

> **Important**: The App Store version will be more limited than the direct version because of sandboxing. Full Disk Access cleanup requires the direct distribution path.

### Build for App Store

```bash
# Archive
xcodebuild archive \
  -scheme Pare \
  -archivePath Pare.xcarchive \
  -destination "generic/platform=macOS"

# Export for App Store
xcodebuild -exportArchive \
  -archivePath Pare.xcarchive \
  -exportPath AppStore \
  -exportOptionsPlist ExportOptions.plist
```

### Submit to App Store Connect

```bash
# Upload using altool or Transporter app
xcrun altool --upload-app \
  -f AppStore/Pare.pkg \
  -t osx \
  -u "your@email.com" \
  -p "app-specific-password"
```

### App Store Metadata

**App Name**: Pare — Mac Disk Cleaner

**Subtitle**: Reclaim disk space, privacy-first

**Description**:
```
Pare is a calmer way to reclaim disk space on your Mac.

Scan your entire Mac to find reclaimable space across 11 categories: system caches, developer tools, duplicate files, large old files, browser data, mail attachments, and more.

Key features:
- Smart Scan finds reclaimable space in seconds
- Space Lens visualises what's taking up your disk
- 30-day Recovery Bin — nothing is permanent
- 100% on-device — no file data ever leaves your Mac
- Beautiful, native macOS interface

Free to use with a 500 MB monthly cleanup cap. Upgrade to Premium for unlimited cleanup, scheduled scans, and cleanup reports.
```

**Keywords**: disk cleaner, storage, cleanup, duplicate finder, cache cleaner, mac cleaner, disk space, system junk, developer tools, uninstaller

**Category**: Utilities

**Price**: Free with in-app purchase ($14.99/year Premium)

### App Store vs Direct — Comparison

| Aspect | Direct (LemonSqueezy) | Mac App Store |
|--------|----------------------|---------------|
| Revenue share | ~95% (5% LS fee) | 70-85% (Apple 15-30%) |
| Sandboxing | None — full disk access | Required — limited scanning |
| Updates | Sparkle or manual | Apple handles |
| Payment | LemonSqueezy | Apple IAP |
| Discoverability | Your marketing | App Store search |
| Review process | None | 1-7 days per update |
| Licence keys | Yes | No — use StoreKit receipts |

### Recommendation

**Ship direct first** (Path 1). It's faster, gives full disk access, and you keep more revenue. Add the App Store version later as a discovery channel with a lighter feature set.

---

## Path 3: Homebrew Cask (Optional)

For developer users who prefer `brew install`:

```bash
# Create a Homebrew Cask formula
# File: homebrew-pare/Casks/pare.rb

cask "pare" do
  version "1.0.0"
  sha256 "SHA256_OF_DMG"

  url "https://github.com/ChessChain/getpare/releases/download/v#{version}/Pare-#{version}.dmg"
  name "Pare"
  desc "Privacy-first disk cleanup app for macOS"
  homepage "https://getpare.lemonsqueezy.com"

  depends_on macos: ">= :ventura"

  app "Pare.app"

  zap trash: [
    "~/Library/Application Support/Pare",
    "~/Library/Preferences/com.clearpath.pare.plist",
    "~/Library/Caches/com.clearpath.pare",
  ]
end
```

Submit to homebrew-cask via PR after your first stable release.

---

## Automated Build Script

Save this as `scripts/release.sh`:

```bash
#!/bin/bash
set -e

VERSION="${1:-1.0.0}"
IDENTITY="Developer ID Application: Your Name (TEAMID)"
APPLE_ID="your@email.com"
APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # app-specific password
TEAM_ID="TEAMID"

echo "=== Building Pare v$VERSION ==="

# 1. Build release
echo "Building..."
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift build -c release

# 2. Create .app bundle
echo "Creating app bundle..."
APP="Pare.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Pare "$APP/Contents/MacOS/Pare"
cp scripts/Info.plist "$APP/Contents/Info.plist"
echo -n "APPL????" > "$APP/Contents/PkgInfo"
# Copy icon if it exists
[ -f "AppIcon.icns" ] && cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Update version in plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"

# 3. Code sign
echo "Signing..."
codesign --force --deep --options runtime --sign "$IDENTITY" --timestamp "$APP"
codesign -dv "$APP"

# 4. Create DMG
echo "Creating DMG..."
DMG="Pare-$VERSION.dmg"
rm -rf dmg-staging
mkdir -p dmg-staging
cp -R "$APP" dmg-staging/
ln -s /Applications dmg-staging/Applications
hdiutil create -volname "Pare $VERSION" -srcfolder dmg-staging -ov -format UDZO "$DMG"
codesign --sign "$IDENTITY" --timestamp "$DMG"
rm -rf dmg-staging

# 5. Notarize
echo "Notarizing..."
xcrun notarytool submit "$DMG" \
  --apple-id "$APPLE_ID" \
  --password "$APP_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait
xcrun stapler staple "$DMG"

# 6. Create GitHub release
echo "Creating GitHub release..."
gh release create "v$VERSION" "$DMG" \
  --title "Pare v$VERSION" \
  --notes "Release v$VERSION"

echo "=== Done! Pare v$VERSION released ==="
echo "DMG: $DMG"
echo "GitHub: https://github.com/ChessChain/getpare/releases/tag/v$VERSION"
```

Make it executable:
```bash
chmod +x scripts/release.sh
```

Run it:
```bash
./scripts/release.sh 1.0.0
```

---

## Checklist Before First Release

- [ ] Apple Developer account enrolled ($99/year)
- [ ] Developer ID Application certificate created
- [ ] App-specific password generated at appleid.apple.com
- [ ] App icon designed (1024x1024 PNG)
- [ ] `scripts/release.sh` configured with your credentials
- [ ] Test: build → sign → notarize → DMG → install on a clean Mac
- [ ] LemonSqueezy products published (Premium + Family)
- [ ] Website updated with download link
- [ ] README.md updated with install instructions
- [ ] Privacy policy page live
- [ ] Support email configured (support@pare.app)

---

## Post-Release: Auto-Updates (Sparkle)

For future versions, integrate [Sparkle](https://sparkle-project.org) for automatic updates:

1. Add Sparkle as a dependency in `Package.swift`
2. Host an `appcast.xml` file with version info
3. The app checks for updates on launch
4. Users get a "Update Available" dialog

This is a v1.1 task — for v1.0, users re-download the DMG from your website.
