#!/usr/bin/env bash
# Zip only the GTNH World folder for sharing. Prompts for episode number; the
# folder inside the zip and the .zip filename become "Hcnureth's World - Episode <N>".
# Live server is never modified.
#
# Usage: gtnh-world-share.sh
# Non-interactive: printf '12\n' | gtnh-world-share.sh
# Install instructions: scripts/gtnh/How to install this world.txt

set -euo pipefail

GTNH_DIR="${GTNH_DIR:-$HOME/Minecraft Servers/gtnh}"

command -v zip >/dev/null || {
  echo "error: zip is required (e.g. apt install zip)" >&2
  exit 1
}

if [[ ! -d "$GTNH_DIR/World" ]]; then
  echo "error: missing $GTNH_DIR/World" >&2
  exit 1
fi

read -r -p "Episode number: " EPISODE
if [[ ! "$EPISODE" =~ ^[[:space:]]*([0-9]+)[[:space:]]*$ ]]; then
  echo "error: enter a positive integer episode number (e.g. 12)" >&2
  exit 1
fi
EPISODE="${BASH_REMATCH[1]}"

WORLD_ZIP_DIR="Hcnureth's World - Episode ${EPISODE}"
OUT_ZIP="$HOME/Desktop/${WORLD_ZIP_DIR}.zip"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

if cp -al "$GTNH_DIR/World" "$STAGE/$WORLD_ZIP_DIR" 2>/dev/null; then
  :
else
  cp -a "$GTNH_DIR/World" "$STAGE/$WORLD_ZIP_DIR"
fi

ZIP_TMP=$(mktemp -u /tmp/gtnh-world-share.XXXXXX.zip)
trap 'rm -rf "$STAGE"; rm -f "$ZIP_TMP"' EXIT

(
  cd "$STAGE"
  zip -r -q "$ZIP_TMP" "$WORLD_ZIP_DIR"
)

rm -f "$OUT_ZIP"
mv "$ZIP_TMP" "$OUT_ZIP"
trap 'rm -rf "$STAGE"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Wrote: $OUT_ZIP"
echo "Install guide (static; upload once to Drive root): $SCRIPT_DIR/How to install this world.txt"
