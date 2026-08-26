#!/usr/bin/env bash
# Build a double-clickable UsageDashboard.app bundle from the SwiftPM release binary.
# Usage: package.sh [version]   (version is also honored via the VERSION env var)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-${VERSION:-0.1.0}}"

swift build -c release

APP="dist/UsageDashboard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Locate the release binary robustly (path varies by SDK/toolchain).
BIN="$(find .build -path '*/release/UsageDashboard' -type f -print -quit)"
if [ -z "$BIN" ]; then
  echo "error: could not locate release binary under .build/" >&2
  exit 1
fi
cp "$BIN" "$APP/Contents/MacOS/UsageDashboard"

# --- Generate the app icon (.icns) from scripts/DrawIcon.swift ---
ICON_PNG="$(mktemp -u /tmp/usage-icon.XXXXXX.png)"
swift scripts/DrawIcon.swift "$ICON_PNG" >/dev/null
ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"
for s in 16 32 128 256 512; do
  d=$((s * 2))
  sips -z "$s" "$s" "$ICON_PNG" --out "$ICONSET_DIR/icon_${s}x${s}.png" >/dev/null
  sips -z "$d" "$d" "$ICON_PNG" --out "$ICONSET_DIR/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$APP/Contents/Resources/AppIcon.icns"
rm -f "$ICON_PNG"
rm -rf "$(dirname "$ICONSET_DIR")"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>UsageDashboard</string>
  <key>CFBundleDisplayName</key><string>UsageDashboard</string>
  <key>CFBundleIdentifier</key><string>local.usagedashboard</string>
  <key>CFBundleExecutable</key><string>UsageDashboard</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc sign the whole bundle so a quarantine-cleared app can launch.
codesign --force --deep --sign - "$APP"

ZIP="dist/UsageDashboard-${VERSION}-macos-arm64.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Built $APP"
echo "Zipped $ZIP"
