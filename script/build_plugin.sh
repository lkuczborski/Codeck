#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
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
cat > "$HELPER_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>codeck-mcp</string>
<key>CFBundleIdentifier</key><string>com.codeck.workspace</string>
<key>CFBundleName</key><string>Codeck Workspace</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>8</string>
<key>CFBundleShortVersionString</key><string>0.3.5</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
chmod +x scripts/run-server.sh build/codeck-mcp "$HELPER_APP/Contents/MacOS/codeck-mcp"
codesign --force --sign - "$HELPER_APP"
PLUGIN_DIST="$ROOT_DIR/dist/codeck-plugin"
mkdir -p "$PLUGIN_DIST/.codex-plugin" "$PLUGIN_DIST/scripts" "$PLUGIN_DIST/build"
cp .codex-plugin/plugin.json "$PLUGIN_DIST/.codex-plugin/plugin.json"
cp .mcp.json README.md "$PLUGIN_DIST/"
cp "$ROOT_DIR/LICENSE" "$PLUGIN_DIST/LICENSE"
cp scripts/run-server.sh "$PLUGIN_DIST/scripts/"
cp build/codeck-mcp build/workspace.html build/workspace.js.LEGAL.txt "$PLUGIN_DIST/build/"
rm -rf "$PLUGIN_DIST/build/Codeck Workspace.app"
cp -R "$HELPER_APP" "$PLUGIN_DIST/build/"
cp -R assets skills "$PLUGIN_DIST/"
echo "Installable plugin built at $PLUGIN_DIST. See plugins/codeck/README.md to install."
