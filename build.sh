#!/bin/bash
# Baut MountBar.app. Mit --install wird die App nach /Applications kopiert und gestartet.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN=$(swift build -c release --show-bin-path)/MountBar

APP=build/MountBar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MountBar"
cp helper/mountbar-helper helper/install-helper.sh "$APP/Contents/Resources/"
chmod 755 "$APP/Contents/Resources/mountbar-helper"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MountBar</string>
    <key>CFBundleDisplayName</key><string>MountBar</string>
    <key>CFBundleIdentifier</key><string>de.leopoldbauer.mountbar</string>
    <key>CFBundleExecutable</key><string>MountBar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSAppleEventsUsageDescription</key><string>MountBar richtet damit einmalig den Helfer mit Administratorrechten ein.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Gebaut: $PWD/$APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x MountBar 2>/dev/null || true
    rm -rf /Applications/MountBar.app
    cp -R "$APP" /Applications/
    open /Applications/MountBar.app
    echo "Installiert und gestartet: /Applications/MountBar.app"
fi
