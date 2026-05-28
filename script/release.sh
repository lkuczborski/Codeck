#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Codeck"
MCP_NAME="codeck-mcp"
BUNDLE_ID="dev.local.Codeck"
MIN_SYSTEM_VERSION="14.0"

usage() {
  cat <<'EOF'
usage: script/release.sh <version> [options]

Build a Codeck macOS release archive matching the GitHub release assets.

Arguments:
  <version>                 Release tag, for example v0.5.

Options:
  --notes-file <path>       Release notes Markdown. Supports {{VERSION}},
                            {{COMMIT}}, {{ZIP_NAME}}, and {{SHA256}}.
  --previous-tag <tag>      Previous tag for generated notes.
  --publish                 Create an annotated tag, push it, and create the
                            GitHub release with the zip and checksum assets.
  --skip-tests              Skip swift test.
  --allow-dirty             Allow a dirty worktree for local package drafts.
  -h, --help                Show this help.

Examples:
  script/release.sh v0.5 --notes-file notes.md
  script/release.sh v0.5 --notes-file notes.md --publish
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

TEMP_PATHS=()

cleanup() {
  local path
  (( ${#TEMP_PATHS[@]} == 0 )) && return

  for path in "${TEMP_PATHS[@]}"; do
    [[ -n "$path" ]] && rm -rf "$path"
  done
}

trap cleanup EXIT

VERSION=""
NOTES_FILE=""
PREVIOUS_TAG=""
PUBLISH=0
SKIP_TESTS=0
ALLOW_DIRTY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes-file)
      [[ $# -ge 2 ]] || die "--notes-file requires a path"
      NOTES_FILE="$2"
      shift 2
      ;;
    --previous-tag)
      [[ $# -ge 2 ]] || die "--previous-tag requires a tag"
      PREVIOUS_TAG="$2"
      shift 2
      ;;
    --publish)
      PUBLISH=1
      shift
      ;;
    --skip-tests)
      SKIP_TESTS=1
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      [[ -z "$VERSION" ]] || die "multiple versions provided"
      VERSION="$1"
      shift
      ;;
  esac
done

[[ -n "$VERSION" ]] || die "version is required"
[[ "$VERSION" =~ ^v[0-9]+([.][0-9]+)*$ ]] || die "version must look like v0.5"

if [[ -n "$NOTES_FILE" ]]; then
  [[ "$NOTES_FILE" = /* ]] || NOTES_FILE="$PWD/$NOTES_FILE"
  [[ -f "$NOTES_FILE" ]] || die "notes file does not exist: $NOTES_FILE"
fi

if (( PUBLISH && ALLOW_DIRTY )); then
  die "--publish cannot be combined with --allow-dirty"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

require_command swift
require_command git
require_command codesign
require_command ditto
require_command lipo
require_command plutil
require_command shasum

if (( PUBLISH )); then
  require_command gh
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"

if (( ! ALLOW_DIRTY )); then
  [[ -z "$(git status --porcelain)" ]] || die "worktree is dirty; commit changes or use --allow-dirty"
fi

if [[ -z "$PREVIOUS_TAG" ]]; then
  PREVIOUS_TAG="$(git tag --sort=-creatordate --merged HEAD | grep -E '^v[0-9]+([.][0-9]+)*$' | grep -v "^${VERSION}$" | head -n 1 || true)"
fi

COMMIT="$(git rev-parse --short HEAD)"
RELEASE_ROOT="$ROOT_DIR/dist/release"
STAGE_ROOT="$RELEASE_ROOT/$VERSION"
PACKAGE_NAME="$APP_NAME-$VERSION-macos-universal"
PACKAGE_DIR="$STAGE_ROOT/$PACKAGE_NAME"
APP_BUNDLE="$PACKAGE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
MCP_BINARY="$PACKAGE_DIR/$MCP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ZIP_NAME="$PACKAGE_NAME.zip"
ZIP_PATH="$RELEASE_ROOT/$ZIP_NAME"
SHA_NAME="$ZIP_NAME.sha256"
SHA_PATH="$RELEASE_ROOT/$SHA_NAME"
NOTES_PATH="$STAGE_ROOT/RELEASE_NOTES.md"

if [[ -n "$NOTES_FILE" ]]; then
  NOTES_TEMPLATE_COPY="$(mktemp "${TMPDIR:-/tmp}/codeck-release-notes.XXXXXX")"
  cp "$NOTES_FILE" "$NOTES_TEMPLATE_COPY"
  TEMP_PATHS+=("$NOTES_TEMPLATE_COPY")
  NOTES_FILE="$NOTES_TEMPLATE_COPY"
fi

assert_universal() {
  local binary="$1"
  local arches
  arches="$(lipo -archs "$binary")"

  [[ " $arches " == *" arm64 "* ]] || die "$binary is missing arm64 architecture: $arches"
  [[ " $arches " == *" x86_64 "* ]] || die "$binary is missing x86_64 architecture: $arches"
}

write_info_plist() {
  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Codeck Deck</string>
      <key>CFBundleTypeIconFile</key>
      <string>DocumentIcon.icns</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Owner</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>dev.local.codeck.mdeck</string>
      </array>
    </dict>
  </array>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>dev.local.codeck.mdeck</string>
      <key>UTTypeDescription</key>
      <string>Codeck Markdown Deck</string>
      <key>UTTypeIconFile</key>
      <string>DocumentIcon.icns</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.plain-text</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>mdeck</string>
        </array>
        <key>public.mime-type</key>
        <string>text/vnd.codeck.deck</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
PLIST
}

generate_notes() {
  {
    echo "Codeck $VERSION"
    echo

    if [[ -n "$PREVIOUS_TAG" ]]; then
      echo "What's new since $PREVIOUS_TAG:"
      git log --pretty=format:'- %s' "$PREVIOUS_TAG..HEAD"
      echo
      echo
    fi

    echo "Download"
    echo "- \`$ZIP_NAME\` contains \`Codeck.app\` and \`$MCP_NAME\` for Apple Silicon and Intel Macs."
    echo "- The app and CLI are ad-hoc signed but not notarized."
    echo "- \`$SHA_NAME\` contains the SHA-256 checksum."
    echo
    echo "Requirements"
    echo "- macOS 14 or later."
    echo "- Codex CLI on \`PATH\` with an active login for live Codex sessions."
    echo
    echo "Validation"
    echo "- Built from commit \`$COMMIT\` with universal \`arm64\` and \`x86_64\` binaries."
    if (( SKIP_TESTS )); then
      echo "- \`swift test\` was skipped."
    else
      echo "- \`swift test\` passed."
    fi
    echo "- \`codesign --verify --deep --strict\` passed for \`Codeck.app\`."
    echo "- Extracted archive verification passed."
    echo "- SHA-256: \`$ZIP_SHA\`."
  } >"$NOTES_PATH"
}

write_notes() {
  if [[ -n "$NOTES_FILE" ]]; then
    sed \
      -e "s/{{VERSION}}/$VERSION/g" \
      -e "s/{{COMMIT}}/$COMMIT/g" \
      -e "s/{{ZIP_NAME}}/$ZIP_NAME/g" \
      -e "s/{{SHA256}}/$ZIP_SHA/g" \
      "$NOTES_FILE" >"$NOTES_PATH"
  else
    generate_notes
  fi
}

publish_release() {
  local current_branch
  local head_commit
  local tag_commit

  current_branch="$(git branch --show-current)"
  [[ -n "$current_branch" ]] || die "cannot publish from detached HEAD"

  head_commit="$(git rev-parse HEAD)"
  if git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null; then
    tag_commit="$(git rev-list -n 1 "$VERSION")"
    [[ "$tag_commit" == "$head_commit" ]] || die "tag $VERSION already points at $tag_commit, not HEAD"
  else
    git tag -a "$VERSION" -F "$NOTES_PATH"
  fi

  if gh release view "$VERSION" >/dev/null 2>&1; then
    die "GitHub release $VERSION already exists"
  fi

  git push origin "$current_branch"
  git push origin "$VERSION"
  gh release create "$VERSION" "$ZIP_PATH" "$SHA_PATH" --title "$VERSION" --notes-file "$NOTES_PATH"
}

if (( ! SKIP_TESTS )); then
  swift test
fi

swift build -c release --arch arm64 --arch x86_64
BUILD_DIR="$(swift build -c release --show-bin-path --arch arm64 --arch x86_64)"

[[ -x "$BUILD_DIR/$APP_NAME" ]] || die "missing built app executable: $BUILD_DIR/$APP_NAME"
[[ -x "$BUILD_DIR/$MCP_NAME" ]] || die "missing built MCP executable: $BUILD_DIR/$MCP_NAME"
assert_universal "$BUILD_DIR/$APP_NAME"
assert_universal "$BUILD_DIR/$MCP_NAME"

rm -rf "$STAGE_ROOT"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"

cp "$BUILD_DIR/$APP_NAME" "$APP_BINARY"
cp "$BUILD_DIR/$MCP_NAME" "$MCP_BINARY"
chmod +x "$APP_BINARY" "$MCP_BINARY"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
cp "$ROOT_DIR/Resources/DocumentIcon.icns" "$APP_RESOURCES/DocumentIcon.icns"
write_info_plist
plutil -lint "$INFO_PLIST" >/dev/null

codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
codesign --force --sign - "$MCP_BINARY" >/dev/null
codesign --verify --deep --strict "$APP_BUNDLE"
codesign --verify --strict "$MCP_BINARY"

rm -f "$ZIP_PATH" "$SHA_PATH"
find "$PACKAGE_DIR" -name .DS_Store -delete
(
  cd "$STAGE_ROOT"
  ditto -c -k --norsrc --noextattr --keepParent "$PACKAGE_NAME" "$ZIP_PATH"
)
(
  cd "$RELEASE_ROOT"
  shasum -a 256 "$ZIP_NAME" >"$SHA_PATH"
)
ZIP_SHA="$(cut -d ' ' -f 1 "$SHA_PATH")"
write_notes

VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codeck-release-verify.XXXXXX")"
TEMP_PATHS+=("$VERIFY_DIR")
ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"
codesign --verify --deep --strict "$VERIFY_DIR/$PACKAGE_NAME/$APP_NAME.app"
codesign --verify --strict "$VERIFY_DIR/$PACKAGE_NAME/$MCP_NAME"

if (( PUBLISH )); then
  publish_release
fi

cat <<EOF
Release package ready:
  $ZIP_PATH
  $SHA_PATH
  $NOTES_PATH

SHA-256:
  $ZIP_SHA
EOF
