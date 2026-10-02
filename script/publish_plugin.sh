#!/usr/bin/env bash
set -euo pipefail

# Run only after tests pass. The package archive contains codeck-plugin/ and a
# local marketplace catalog; no source tree or installed credentials are copied.
PACKAGE_ROOT="${1:?Provide the extracted package directory}"
RELEASE_REMOTE="${2:?Provide the destination repository URL}"
SOURCE_COMMIT="${3:?Provide the tested source commit}"
DISTRIBUTION_REF="codex/plugin-distribution"

RELEASE_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/codeck-publish.XXXXXX")"
trap 'rm -rf "$RELEASE_DIRECTORY"' EXIT
git init -q "$RELEASE_DIRECTORY"
cd "$RELEASE_DIRECTORY"
git remote add origin "$RELEASE_REMOTE"
if [[ -n "${GH_TOKEN:-}" ]]; then
  git config credential.helper '!f() { printf "%s\n" "username=x-access-token" "password=$GH_TOKEN"; }; f'
fi

# Old workflow reruns cannot replace the current main branch's package.
CURRENT_SOURCE="$(git ls-remote origin refs/heads/main | cut -f1)"
if [[ "$CURRENT_SOURCE" != "$SOURCE_COMMIT" ]]; then
  echo 'Skipping publication: main has moved beyond this tested source commit.'
  exit 0
fi
if [[ -n "$(git ls-remote origin "refs/heads/$DISTRIBUTION_REF")" ]]; then
  git fetch -q --depth=1 origin "$DISTRIBUTION_REF"
  git checkout -q -b "$DISTRIBUTION_REF" FETCH_HEAD
  git rm -q -r --ignore-unmatch .
else
  git checkout -q --orphan "$DISTRIBUTION_REF"
fi
cp -R "$PACKAGE_ROOT/codeck-plugin" ./codeck-plugin
mkdir -p .agents/plugins
cp "$PACKAGE_ROOT/.agents/plugins/marketplace.json" .agents/plugins/marketplace.json
node --input-type=module <<'JS'
import { readFile, writeFile } from 'node:fs/promises';
const file = '.agents/plugins/marketplace.json';
const catalog = JSON.parse(await readFile(file, 'utf8'));
catalog.name = 'codeck-plugins';
catalog.interface.displayName = 'Codeck Plugins';
await writeFile(file, JSON.stringify(catalog, null, 2) + '\n');
JS
printf '%s\n' "$SOURCE_COMMIT" > SOURCE_COMMIT
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add .
if git diff --cached --quiet; then
  echo 'The tested package is already published.'
  exit 0
fi
git commit -q -m "Package Codeck from $SOURCE_COMMIT"
# Use an ordinary push: concurrent or unexpected changes must not be overwritten.
git push origin "HEAD:refs/heads/$DISTRIBUTION_REF"
