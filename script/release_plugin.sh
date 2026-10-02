#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == '--help' || "${1:-}" == '-h' ]]; then
  cat <<'HELP'
usage: script/release_plugin.sh [--publish]

Build, test, Developer ID sign, and notarize a plugin locally.
--publish promotes the current main source to the repository marketplace branch.
Set CODECK_SIGNING_IDENTITY and CODECK_NOTARY_PROFILE to existing Keychain entries.
Use a clean committed checkout; feature branches can produce local candidates.
HELP
  exit 0
fi
[[ $# -eq 0 || ( $# -eq 1 && "$1" == '--publish' ) ]] \
  || { echo 'Only --publish is supported' >&2; exit 1; }
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
[[ -z "$(git status --porcelain)" ]] || { echo 'Commit source changes before releasing' >&2; exit 1; }
SOURCE_COMMIT="$(git rev-parse HEAD)"
RELEASE_REMOTE='https://github.com/lkuczborski/Codeck.git'
if [[ "${1:-}" == '--publish' ]]; then
  [[ "$(git ls-remote "$RELEASE_REMOTE" refs/heads/main | cut -f1)" == "$SOURCE_COMMIT" ]] \
    || { echo 'Merge this committed source to main before publishing' >&2; exit 1; }
fi
: "${CODECK_SIGNING_IDENTITY:?Set a Developer ID Application identity}"
: "${CODECK_NOTARY_PROFILE:?Set the notarytool Keychain profile}"
# Marketplace versions are explicit source versions, rather than CI run numbers.
unset CODECK_PLUGIN_BUILD_NUMBER
script/build_plugin.sh
script/build_and_run.sh --package
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f dist/Codeck.app
swift test
CODECK_MCP_EXECUTABLE="$ROOT_DIR/dist/codeck-plugin/build/codeck-mcp" npm --prefix plugins/codeck run typecheck
CODECK_MCP_EXECUTABLE="$ROOT_DIR/dist/codeck-plugin/build/codeck-mcp" npm --prefix plugins/codeck test
[[ -z "$(git status --porcelain)" ]] || { echo 'The build changed tracked source; review and commit it before releasing' >&2; exit 1; }
script/notarize_plugin.sh "$ROOT_DIR/dist" "$SOURCE_COMMIT"
VERSION="$(node -p "require('./plugins/codeck/.codex-plugin/plugin.json').version")"
if [[ "${1:-}" == '--publish' ]]; then
  script/publish_plugin.sh "$ROOT_DIR/dist/plugin-release/$VERSION/package" "$RELEASE_REMOTE" "$SOURCE_COMMIT"
fi
