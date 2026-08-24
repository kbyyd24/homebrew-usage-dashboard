#!/bin/bash
# Build a double-clickable UsageDash.app bundle from the SwiftPM release binary.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

APP="dist/UsageDash.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/UsageDash "$APP/Contents/MacOS/UsageDash"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>UsageDash</string>
    <key>CFBundleIdentifier</key>
    <string>dev.local.usagedash</string>
    <key>CFBundleName</key>
    <string>UsageDash</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "Built $APP"
