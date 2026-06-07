#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "error: swiftformat is not installed. Install project tools with: brew bundle" >&2
  exit 127
fi

cd "$ROOT_DIR"
swiftformat --cache ignore Package.swift Sources Tests
