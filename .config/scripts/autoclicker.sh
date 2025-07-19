#!/bin/bash

# Configuration
CLICK_INTERVAL_MS=10       # Interval between clicks in milliseconds
MOUSE_BUTTON=0xC0          # Left Click

# Internal variables (do not modify)
PID_FILE="/tmp/autoclicker_pid.tmp"
LOG_FILE="/tmp/autoclicker_log.tmp" # For debugging if needed
NOTIFY_APP="Autoclicker"

# Function to perform clicks
autoclick_loop() {
    local interval_ms=$1
    local button=$2

    while true; do
        ydotool click $button
        sleep "$(echo "scale=3; $interval_ms / 1000" | bc)" # Convert ms to seconds for sleep
        # Exit if the PID file is removed (signal to stop)
        [ ! -f "$PID_FILE" ] && break
    done
    echo "Autoclicker loop exited." >> "$LOG_FILE"
}

# Main logic for toggling
if [ -f "$PID_FILE" ]; then
    # Autoclicker is running, stop it
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then # Check if process exists
        kill "$PID"
        rm "$PID_FILE"
        echo "$(date): Autoclicker stopped (PID: $PID)" >> "$LOG_FILE"
    else
        # PID file exists but process doesn't, clean up
        rm "$PID_FILE"
        echo "$(date): Cleaned up stale PID file. ($PID)" >> "$LOG_FILE"
    fi
    notify-send -t 2000 "$NOTIFY_APP: OFF"
else
    # Autoclicker is not running, start it
    notify-send -t 2000 "$NOTIFY_APP: ON" "Interval: ${CLICK_INTERVAL_MS}ms"
    echo "$(date): Autoclicker starting (Interval: ${CLICK_INTERVAL_MS}ms, Button: ${MOUSE_BUTTON})" >> "$LOG_FILE"

    # Start the clicking loop in the background
    autoclick_loop "$CLICK_INTERVAL_MS" "$MOUSE_BUTTON" &
    echo $! > "$PID_FILE" # Save the PID of the background process
    echo "$(date): Autoclicker started with PID $! (Interval: ${CLICK_INTERVAL_MS}ms, Button: ${MOUSE_BUTTON})" >> "$LOG_FILE"
fi