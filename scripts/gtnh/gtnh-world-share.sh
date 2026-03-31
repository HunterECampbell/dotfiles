#!/usr/bin/env bash
# Zip only the GTNH World folder for sharing. Prompts for episode number; the
# folder inside the zip and the .zip filename become "Hcnureths World Episode <N>"
# (no apostrophe or hyphen — friendlier for Drive / some tools).
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
python3 -c "import nbtlib" 2>/dev/null || {
  echo "error: nbtlib is required to patch level.dat (pip install nbtlib)" >&2
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

WORLD_ZIP_DIR="Hcnureths World Episode ${EPISODE}"
OUT_ZIP="$HOME/Desktop/${WORLD_ZIP_DIR}.zip"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

if cp -al "$GTNH_DIR/World" "$STAGE/$WORLD_ZIP_DIR" 2>/dev/null; then
  :
else
  cp -a "$GTNH_DIR/World" "$STAGE/$WORLD_ZIP_DIR"
fi

# Break hardlink on level.dat so NBT edits never touch the live server copy
LEVEL_DAT="$STAGE/$WORLD_ZIP_DIR/level.dat"
if [[ -f "$LEVEL_DAT" ]]; then
  cp -a "$LEVEL_DAT" "${LEVEL_DAT}.unlinktmp"
  mv -f "${LEVEL_DAT}.unlinktmp" "$LEVEL_DAT"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/gtnh_world_share_patch_level.py" "$STAGE/$WORLD_ZIP_DIR" || exit 1

ZIP_TMP=$(mktemp -u /tmp/gtnh-world-share.XXXXXX.zip)
trap 'rm -rf "$STAGE"; rm -f "$ZIP_TMP"' EXIT

(
  cd "$STAGE"
  zip -r -q "$ZIP_TMP" "$WORLD_ZIP_DIR"
)

rm -f "$OUT_ZIP"
mv "$ZIP_TMP" "$OUT_ZIP"
trap 'rm -rf "$STAGE"' EXIT

echo "Wrote: $OUT_ZIP"
echo "Install guide (static; upload once to Drive root): $SCRIPT_DIR/How to install this world.txt"
