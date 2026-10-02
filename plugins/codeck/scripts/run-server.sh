#!/usr/bin/env bash
set -euo pipefail
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -x "$PLUGIN_ROOT/build/codeck-mcp" || ! -f "$PLUGIN_ROOT/build/workspace.html" ]]; then
  echo 'Codeck plugin is not built. Run script/build_plugin.sh in the Codeck repository.' >&2
  exit 1
fi
export CODECK_WORKSPACE_UI_PATH="$PLUGIN_ROOT/build/workspace.html"
WORKSPACE_ROOT="${CODECK_MCP_WORKING_DIRECTORY:-${CODECK_MCP_ALLOWED_ROOTS:-}}"
WORKSPACE_ROOT="${WORKSPACE_ROOT%%:*}"
if [[ -z "$WORKSPACE_ROOT" ]]; then
  WORKSPACE_ROOT="$HOME/Documents/Codeck"
  mkdir -p "$WORKSPACE_ROOT"
fi
cd "$WORKSPACE_ROOT"
exec "$PLUGIN_ROOT/build/Codeck Workspace.app/Contents/MacOS/codeck-mcp"
