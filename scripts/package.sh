#!/usr/bin/env bash
# Build a double-clickable UsageDashboard.app bundle from the SwiftPM release binary.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/UsageDashboard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/arm64-apple-macosx/release/UsageDashboard "$APP/Contents/MacOS/UsageDashboard"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>UsageDashboard</string>
  <key>CFBundleDisplayName</key><string>UsageDashboard</string>
  <key>CFBundleIdentifier</key><string>local.usagedashboard</string>
  <key>CFBundleExecutable</key><string>UsageDashboard</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "Built $APP"
