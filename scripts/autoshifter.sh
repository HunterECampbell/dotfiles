#!/bin/bash

# =============================================================================
# Autoshifter - Toggleable auto-shift key presser
# =============================================================================
# This script repeatedly presses the Shift key at a configurable interval.
# Running it again while active will toggle it off.
#
# Dependencies: xdotool (sudo apt install xdotool)
# Usage: ./autoshifter.sh
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration - Modify this value to change the interval between key presses
# -----------------------------------------------------------------------------
INTERVAL_MS=1

# -----------------------------------------------------------------------------
# Internal variables (do not modify)
# -----------------------------------------------------------------------------
PID_FILE="/tmp/autoshifter.pid"

# -----------------------------------------------------------------------------
# Toggle logic
# -----------------------------------------------------------------------------

# Check if an instance is already running
if [[ -f "$PID_FILE" ]]; then
    EXISTING_PID=$(cat "$PID_FILE")

    # Check if the process is still running
    if kill -0 "$EXISTING_PID" 2>/dev/null; then
        # Process is running - kill it (toggle OFF)
        kill "$EXISTING_PID" 2>/dev/null
        rm -f "$PID_FILE"
        exit 0
    else
        # PID file exists but process is dead - clean up stale PID file
        rm -f "$PID_FILE"
    fi
fi

# -----------------------------------------------------------------------------
# Start the autoshifter in the background (toggle ON)
# -----------------------------------------------------------------------------

# Launch background process
(
    # Cleanup function for the background process
    cleanup() {
        rm -f "$PID_FILE"
        exit 0
    }

    # Set up cleanup trap for signals
    trap cleanup SIGTERM SIGINT SIGHUP

    # Main loop - use xdotool's native repeat for accurate timing
    # --repeat 1000 --delay $MS handles timing internally without process spawn overhead
    # Loop ensures it continues indefinitely
    while true; do
        xdotool key --repeat 1000 --delay "$INTERVAL_MS" shift
    done
) &

# Save the background process PID
echo $! > "$PID_FILE"

# Exit immediately so keybind can be triggered again
exit 0
