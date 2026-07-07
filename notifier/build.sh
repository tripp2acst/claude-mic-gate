#!/usr/bin/env bash
# build.sh — compile the notifier into a signed .app bundle.
#   Usage: build.sh [dest-dir]   (default: ~/.claude/hooks)
# Produces <dest-dir>/ClaudeMicGate.app
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$HOME/.claude/hooks}"
APP="$DEST/ClaudeMicGate.app"
BUNDLE_ID="com.claudemicgate.notifier"

command -v swiftc >/dev/null 2>&1 || { echo "error: swiftc not found (xcode-select --install)" >&2; exit 1; }
[[ -f "$SRC_DIR/icon.icns" ]] || { echo "error: icon.icns missing next to build.sh" >&2; exit 1; }

mkdir -p "$DEST"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling notifier..."
swiftc -O "$SRC_DIR/main.swift" -o "$APP/Contents/MacOS/Notifier"

cp "$SRC_DIR/icon.icns" "$APP/Contents/Resources/icon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>          <string>claude-mic-gate</string>
  <key>CFBundleDisplayName</key>   <string>claude-mic-gate</string>
  <key>CFBundleIdentifier</key>    <string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key>    <string>Notifier</string>
  <key>CFBundleIconFile</key>      <string>icon</string>
  <key>CFBundlePackageType</key>   <string>APPL</string>
  <key>CFBundleShortVersionString</key> <string>1.0</string>
  <key>CFBundleVersion</key>       <string>1</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSUIElement</key>           <true/>
  <key>NSPrincipalClass</key>      <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so UserNotifications accepts a stable identity, then register with
# LaunchServices so a click can relaunch the app to handle the tap.
echo "Signing (ad-hoc)..."
codesign --force --deep -s - "$APP" >/dev/null 2>&1 || echo "warning: codesign failed; notifications may not post"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[[ -x "$LSREGISTER" ]] && "$LSREGISTER" -f "$APP" || true

echo "Built $APP"
