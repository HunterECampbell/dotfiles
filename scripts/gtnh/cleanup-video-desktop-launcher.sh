#!/usr/bin/env bash
# Desktop launcher: run cleanup-video.py then wait so the terminal stays open.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"
/usr/bin/python3 "$SCRIPT_DIR/cleanup-video.py" "$@"
ec=$?
echo
read -r -p "Press Enter to close... " || true
exit "$ec"
