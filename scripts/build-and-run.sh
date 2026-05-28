#!/bin/bash
# Build Pare and install to /Applications with proper bundle structure
set -e

SWIFT=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift
APP=/Applications/Pare.app
BUNDLE_ID=com.clearpath.pare

echo "Building Pare..."
$SWIFT build 2>&1 | tail -3

echo "Killing old instance..."
killall Pare 2>/dev/null || true
sleep 1

echo "Installing to $APP..."
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp .build/debug/Pare "$APP/Contents/MacOS/Pare"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

# Write Info.plist
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
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>Pare needs access to scan and clean system files.</string>
</dict>
</plist>
EOF

# Sign the bundle
codesign --force --deep --sign - "$APP" 2>/dev/null

# Register with Launch Services
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null

echo "Launching Pare..."
open "$APP"
echo "Done."
