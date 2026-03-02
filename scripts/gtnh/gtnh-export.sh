#!/usr/bin/env bash
# GTNH Data Export - Extracts gameplay data to JSON for Claude AI agent context.
# Output: gtnh_static.json, gtnh_session.json on Desktop

set -euo pipefail

SERVER_ROOT="$HOME/Minecraft Servers/gtnh"
OUTPUT_DIR="$HOME/Desktop"
PLAYER_UUID="e4592d69-b3d6-45fe-ad62-ca1f3b1bbb0e"
PLAYER_NAME="Hcnureth"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check nbtlib dependency
python3 -c "import nbtlib" 2>/dev/null || {
    echo "Missing nbtlib. Install with: pip install nbtlib"
    exit 1
}

# Parse args
SESSION_ONLY=false
STATIC_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --session-only) SESSION_ONLY=true ;;
        --static-only)  STATIC_ONLY=true ;;
    esac
done

# Build Python args
PYTHON_ARGS=("$SERVER_ROOT" "$OUTPUT_DIR" "$PLAYER_UUID" "$PLAYER_NAME")
if $SESSION_ONLY; then
    PYTHON_ARGS+=(--session-only)
elif $STATIC_ONLY; then
    PYTHON_ARGS+=(--static-only)
fi

exec python3 "$SCRIPT_DIR/gtnh_export.py" "${PYTHON_ARGS[@]}"
