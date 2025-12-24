#!/bin/bash

# =============================================================================
# Autoshifter - Toggleable auto-shift key presser
# =============================================================================
# This script repeatedly presses the Shift key at a configurable interval.
# Running it again while active will toggle it off.
# Press mouse button 8 (side button) to stop at any time.
#
# Dependencies: xdotool (sudo apt install xdotool), xinput
# Usage: ./autoshifter.sh
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration - Modify these values as needed
# -----------------------------------------------------------------------------
INTERVAL_MS=10
MOUSE_STOP_BUTTON=8  # Mouse button to stop the script (8 = side button back)

# -----------------------------------------------------------------------------
# Internal variables (do not modify)
# -----------------------------------------------------------------------------
PID_FILE="/tmp/autoshifter.pid"
MONITOR_PID_FILE="/tmp/autoshifter_monitor.pid"
LOCK_FILE="/tmp/autoshifter.lock"
SCRIPT_NAME="autoshifter.sh"

# -----------------------------------------------------------------------------
# Prevent multiple simultaneous invocations using a lock file
# -----------------------------------------------------------------------------
exec 200>"$LOCK_FILE"
flock -n 200 || exit 0

# -----------------------------------------------------------------------------
# Kill function - aggressively kills ALL autoshifter processes
# -----------------------------------------------------------------------------
kill_all_autoshifters() {
    # Kill all xdotool shift processes
    pkill -9 -f "xdotool key --repeat.*shift" 2>/dev/null

    # Kill mouse monitor if running
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        kill -9 "$(cat "$MONITOR_PID_FILE")" 2>/dev/null
        rm -f "$MONITOR_PID_FILE"
    fi

    # Kill any xinput monitors for this script
    pkill -9 -f "xinput test-xi2.*autoshifter" 2>/dev/null

    # Kill all autoshifter.sh subshell processes (but not this script)
    pgrep -f "$SCRIPT_NAME" | grep -v $$ | xargs -r kill -9 2>/dev/null

    # Clean up PID file
    rm -f "$PID_FILE"
}

# -----------------------------------------------------------------------------
# Toggle logic - kills ALL autoshifter processes, not just a specific PID
# -----------------------------------------------------------------------------

# Check if any autoshifter xdotool processes are running
if pgrep -f "xdotool key --repeat.*shift" > /dev/null 2>&1 || [[ -f "$PID_FILE" ]]; then
    kill_all_autoshifters
    exit 0
fi

# -----------------------------------------------------------------------------
# Start the autoshifter in the background (toggle ON)
# -----------------------------------------------------------------------------

# Launch shift loop in background
(
    # Main loop - use xdotool's native repeat for accurate timing
    while true; do
        xdotool key --repeat 1000 --delay "$INTERVAL_MS" shift
    done
) &
SHIFT_PID=$!

# Save the shift process PID
echo $SHIFT_PID > "$PID_FILE"

# -----------------------------------------------------------------------------
# Start mouse button monitor in background
# -----------------------------------------------------------------------------
(
    # Wait for the specific mouse button press using xinput
    # xinput outputs multi-line events, so we use awk to track state
    # When RawButtonPress with our button is detected, kill the shift process
    xinput test-xi2 --root 2>/dev/null | awk -v btn="$MOUSE_STOP_BUTTON" -v pid="$SHIFT_PID" -v pidfile="$PID_FILE" -v monfile="$MONITOR_PID_FILE" '
        /RawButtonPress/ { in_button_press = 1 }
        /RawButtonRelease/ { in_button_press = 0 }
        in_button_press && /detail:/ {
            split($0, a, ":")
            gsub(/[^0-9]/, "", a[2])
            if (a[2] == btn) {
                system("kill -9 " pid " 2>/dev/null")
                system("pkill -9 -f \"xdotool key --repeat.*shift\" 2>/dev/null")
                system("rm -f " pidfile " " monfile)
                exit 0
            }
        }
    '
) &
MONITOR_PID=$!

# Save the monitor PID
echo $MONITOR_PID > "$MONITOR_PID_FILE"

# Exit immediately so keybind can be triggered again
exit 0
