#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: script/notarize_plugin.sh <package-root> [source-commit]

Sign and notarize a built plugin locally, then verify its extracted ZIP.
The input directory contains codeck-plugin/ and .agents/plugins/marketplace.json.
CI packages also contain SOURCE_COMMIT. For a local build, pass its tested commit.
Set CODECK_SIGNING_IDENTITY and CODECK_NOTARY_PROFILE to existing Keychain entries.
Output: dist/plugin-release/<version>/package and a distributable ZIP/checksum.
EOF
}
if [[ "${1:-}" == '--help' || "${1:-}" == '-h' ]]; then usage; exit 0; fi
INPUT_ROOT="${1:?Provide the extracted CI artifact or local dist directory}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_ROOT="$(cd "$INPUT_ROOT" && pwd)"
SOURCE_COMMIT="${2:-$(cat "$INPUT_ROOT/SOURCE_COMMIT" 2>/dev/null || true)}"
[[ "$SOURCE_COMMIT" =~ ^[a-f0-9]{40}$ ]] || { echo 'Provide the full tested source commit' >&2; exit 1; }
SIGNING_IDENTITY="${CODECK_SIGNING_IDENTITY:?Set a Developer ID Application identity}"
NOTARY_PROFILE="${CODECK_NOTARY_PROFILE:?Set the notarytool Keychain profile}"
[[ "$SIGNING_IDENTITY" == 'Developer ID Application:'* ]] || { echo 'A Developer ID Application identity is required' >&2; exit 1; }
security find-identity -v -p codesigning | grep -F -- "\"$SIGNING_IDENTITY\"" >/dev/null
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null

VERSION="$(node -p "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')).version" "$INPUT_ROOT/codeck-plugin/.codex-plugin/plugin.json")"
[[ "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+(-build[.][0-9]+)?$ ]] || { echo 'Unexpected plugin version' >&2; exit 1; }
RELEASE_ROOT="$ROOT_DIR/dist/plugin-release/$VERSION"
PACKAGE_ROOT="$RELEASE_ROOT/package"
[[ "$INPUT_ROOT" != "$PACKAGE_ROOT" ]] || { echo 'Input must be the original unsigned package' >&2; exit 1; }
mkdir -p "$RELEASE_ROOT"
rm -rf "$PACKAGE_ROOT"
mkdir -p "$PACKAGE_ROOT/.agents/plugins"
ditto "$INPUT_ROOT/codeck-plugin" "$PACKAGE_ROOT/codeck-plugin"
cp "$INPUT_ROOT/.agents/plugins/marketplace.json" "$PACKAGE_ROOT/.agents/plugins/marketplace.json"
printf '%s\n' "$SOURCE_COMMIT" > "$PACKAGE_ROOT/SOURCE_COMMIT"
HELPER_APP="$PACKAGE_ROOT/codeck-plugin/build/Codeck Workspace.app"
MCP_BINARY="$PACKAGE_ROOT/codeck-plugin/build/codeck-mcp"
[[ "$(plutil -extract CFBundleIdentifier raw "$HELPER_APP/Contents/Info.plist")" == 'com.luku.Codeck.workspace' ]] \
  || { echo 'Unexpected workspace bundle identifier' >&2; exit 1; }
codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$MCP_BINARY"
codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$HELPER_APP"
codesign --verify --strict "$MCP_BINARY"
codesign --verify --strict "$HELPER_APP"

SUBMISSION_ZIP="$RELEASE_ROOT/submission.zip"
rm -f "$SUBMISSION_ZIP"
ditto -c -k --norsrc --noextattr "$PACKAGE_ROOT" "$SUBMISSION_ZIP"
xcrun notarytool submit "$SUBMISSION_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait \
  --output-format json > "$PACKAGE_ROOT/NOTARIZATION.json"
node --input-type=module - "$PACKAGE_ROOT/NOTARIZATION.json" "$SOURCE_COMMIT" <<'JS'
import { readFileSync, writeFileSync } from 'node:fs';
const [file, sourceCommit] = process.argv.slice(2);
const receipt = JSON.parse(readFileSync(file, 'utf8'));
if (receipt.status !== 'Accepted') throw new Error(`Apple notarization ${receipt.status}: ${receipt.id}`);
writeFileSync(file, JSON.stringify({ ...receipt, sourceCommit }, null, 2) + '\n');
JS
xcrun stapler staple "$HELPER_APP"
"$ROOT_DIR/script/verify_plugin.sh" "$PACKAGE_ROOT"

ZIP_NAME="Codeck-plugin-$VERSION-macos-arm64.zip"
ZIP_PATH="$RELEASE_ROOT/$ZIP_NAME"
rm -f "$ZIP_PATH"
ditto -c -k --norsrc --noextattr "$PACKAGE_ROOT" "$ZIP_PATH"
VERIFY_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codeck-plugin-verify.XXXXXX")"
trap 'rm -rf "$VERIFY_ROOT"' EXIT
ditto -x -k "$ZIP_PATH" "$VERIFY_ROOT"
"$ROOT_DIR/script/verify_plugin.sh" "$VERIFY_ROOT"
(cd "$RELEASE_ROOT" && shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256")
echo "Notarized plugin: $ZIP_PATH"
echo "Package to publish after merging: $PACKAGE_ROOT"
