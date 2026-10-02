#!/usr/bin/env bash
set -euo pipefail

PACKAGE_ROOT="${1:?Provide the notarized package directory}"
HELPER_APP="$PACKAGE_ROOT/codeck-plugin/build/Codeck Workspace.app"
MCP_BINARY="$PACKAGE_ROOT/codeck-plugin/build/codeck-mcp"
RECEIPT="$PACKAGE_ROOT/NOTARIZATION.json"

node --input-type=module - "$RECEIPT" "$PACKAGE_ROOT/SOURCE_COMMIT" <<'JS'
import { readFileSync } from 'node:fs';
const [receiptPath, sourcePath] = process.argv.slice(2);
const receipt = JSON.parse(readFileSync(receiptPath, 'utf8'));
const source = readFileSync(sourcePath, 'utf8').trim();
if (receipt.status !== 'Accepted' || !receipt.id || receipt.sourceCommit !== source || !/^[a-f0-9]{40}$/.test(source)) {
  throw new Error('An accepted notarization receipt for this source commit is required');
}
JS

[[ "$(plutil -extract CFBundleIdentifier raw "$HELPER_APP/Contents/Info.plist")" == 'com.luku.Codeck.workspace' ]] \
  || { echo 'Unexpected workspace bundle identifier' >&2; exit 1; }
for binary in "$MCP_BINARY" "$HELPER_APP"; do
  codesign --verify --strict "$binary"
  details="$(codesign -dvvv "$binary" 2>&1)"
  [[ "$details" == *'Authority=Developer ID Application:'* && "$details" == *'runtime'* && "$details" == *'Timestamp='* ]] \
    || { echo "Developer ID, hardened runtime, and a secure timestamp are required: $binary" >&2; exit 1; }
done
xcrun stapler validate "$HELPER_APP"
spctl --assess --type execute --verbose "$HELPER_APP"
