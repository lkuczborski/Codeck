#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
PLUGIN_VERSION="$(node -p "require('./plugins/codeck/.codex-plugin/plugin.json').version")"
PLUGIN_BUILD_NUMBER="${CODECK_PLUGIN_BUILD_NUMBER:-9}"
swift build -c release --product codeck-mcp
BIN_DIR="$(swift build -c release --show-bin-path)"
cd "$ROOT_DIR/plugins/codeck"
sips -s format png "$ROOT_DIR/Resources/AppIcon.icns" --out assets/app-icon.png >/dev/null
npm ci
npm run build
cp "$BIN_DIR/codeck-mcp" build/codeck-mcp
HELPER_APP="build/Codeck Workspace.app"
mkdir -p "$HELPER_APP/Contents/MacOS" "$HELPER_APP/Contents/Resources"
cp build/codeck-mcp "$HELPER_APP/Contents/MacOS/codeck-mcp"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$HELPER_APP/Contents/Resources/AppIcon.icns"
cat > "$HELPER_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>codeck-mcp</string>
<key>CFBundleIdentifier</key><string>com.codeck.workspace</string>
<key>CFBundleName</key><string>Codeck Workspace</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>$PLUGIN_BUILD_NUMBER</string>
<key>CFBundleShortVersionString</key><string>$PLUGIN_VERSION</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
chmod +x scripts/run-server.sh build/codeck-mcp "$HELPER_APP/Contents/MacOS/codeck-mcp"
codesign --force --sign - "$HELPER_APP"
node "$ROOT_DIR/script/stage_plugin.mjs"
echo "Install with: codex plugin marketplace add $ROOT_DIR/dist"
