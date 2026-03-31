#!/usr/bin/env bash
# Build a zip of World + journeymap (+ visualprospecting) for sharing. Live server is never modified.
# Install instructions: static file How to install this world.txt (commit in repo; upload once to Drive).

set -euo pipefail

GTNH_DIR="${GTNH_DIR:-$HOME/Minecraft Servers/gtnh}"
ZIP_NAME="world-and-map-EPISODE-.zip"
OUT_ZIP="$HOME/Desktop/$ZIP_NAME"

command -v zip >/dev/null || {
  echo "error: zip is required (e.g. apt install zip)" >&2
  exit 1
}

if [[ ! -d "$GTNH_DIR/World" ]]; then
  echo "error: missing $GTNH_DIR/World" >&2
  exit 1
fi
if [[ ! -d "$GTNH_DIR/journeymap" ]]; then
  echo "error: missing $GTNH_DIR/journeymap" >&2
  exit 1
fi

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

mkdir "$STAGE/World and Map"

copy_tree() {
  local name="$1"
  local src="$GTNH_DIR/$name"
  local dst="$STAGE/World and Map/$name"
  [[ -e "$src" ]] || return 0
  if cp -al "$src" "$dst" 2>/dev/null; then
    return 0
  fi
  cp -a "$src" "$dst"
}

copy_tree World
copy_tree journeymap
copy_tree visualprospecting

# mktemp -u: path must not exist yet (empty file makes zip report "structure invalid")
ZIP_TMP=$(mktemp -u /tmp/gtnh-world-share.XXXXXX.zip)
trap 'rm -rf "$STAGE"; rm -f "$ZIP_TMP"' EXIT

(
  cd "$STAGE"
  zip -r -q "$ZIP_TMP" "World and Map"
)

rm -f "$OUT_ZIP"
mv "$ZIP_TMP" "$OUT_ZIP"
trap 'rm -rf "$STAGE"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Wrote: $OUT_ZIP"
echo "Install guide (static; upload once to Drive root): $SCRIPT_DIR/How to install this world.txt"
