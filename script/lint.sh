#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

missing_tools=()
for tool in swiftformat swiftlint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing_tools+=("$tool")
  fi
done

if ((${#missing_tools[@]})); then
  echo "error: missing ${missing_tools[*]}. Install project tools with: brew bundle" >&2
  exit 127
fi

cd "$ROOT_DIR"
swiftformat --cache ignore --lint Package.swift Sources Tests
swiftlint lint --no-cache
