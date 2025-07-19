#!/bin/bash

# Configuration
CLICK_INTERVAL_MS=10       # Interval between clicks in milliseconds
MOUSE_CLICK_CODE=0xC0      # Left Click (0xC0 for Left, 0xC1 for Right, 0xC2 for Middle)

# Internal variables (do not modify)
AUTOCLICK_PID_FILE="/tmp/autoclicker_loop_pid.tmp" # PID for the autoclick loop
YDOTOOLD_PID_FILE="/tmp/ydotoold_daemon_pid.tmp" # PID for the ydotoold daemon
NOTIFY_APP="Autoclicker"
YDO_SOCKET="/run/user/$(id -u)/.ydotool_socket" # Path to the ydotoold socket

# Function to perform clicks
autoclick_loop() {
    local interval_ms=$1
    local click_code=$2

    while true; do
        # Verify ydotoold socket is present and active within the loop
        if [ ! -S "$YDO_SOCKET" ]; then
            notify-send -u critical "$NOTIFY_APP Error" "ydotoold socket missing. Autoclicker stopped."
            break # Exit loop if socket is gone
        fi

        ydotool click "$click_code" > /dev/null 2>&1 || {
            local ydo_exit_status=$?
            notify-send -u critical "$NOTIFY_APP Error" "ydotool click failed ($ydo_exit_status). Check manual."
            break # Exit loop if click fails
        }
        sleep "$(echo "scale=3; $interval_ms / 1000" | bc)" # Convert ms to seconds for sleep

        # Exit if the autoclick loop PID file is removed (signal to stop)
        [ ! -f "$AUTOCLICK_PID_FILE" ] && break
    done
}

# Main logic for toggling
if [ -f "$AUTOCLICK_PID_FILE" ]; then
    # Autoclicker is running, stop it
    AC_PID=$(cat "$AUTOCLICK_PID_FILE")

    if kill -0 "$AC_PID" 2>/dev/null; then # Check if autoclick loop process exists
        kill "$AC_PID"
        rm "$AUTOCLICK_PID_FILE"
    else
        # Autoclick PID file exists but process doesn't, clean up
        rm "$AUTOCLICK_PID_FILE"
    fi

    # *** Stop ydotoold daemon when autoclicker is turned OFF ***
    if [ -f "$YDOTOOLD_PID_FILE" ]; then
        YDO_PID=$(cat "$YDOTOOLD_PID_FILE")
        if kill -0 "$YDO_PID" 2>/dev/null; then # Check if ydotoold process exists
            kill "$YDO_PID"
            rm "$YDOTOOLD_PID_FILE"
        else
            # ydotoold PID file exists but process doesn't, clean up
            rm "$YDOTOOLD_PID_FILE"
        fi
    fi

    # Final notification for autoclicker off
    notify-send -t 2000 "$NOTIFY_APP: OFF" "Autoclicker is now OFF."

else
    # Autoclicker is not running, start it

    # *** Start ydotoold daemon when autoclicker is turned ON ***
    if [ -f "$YDOTOOLD_PID_FILE" ]; then
        YDO_PID=$(cat "$YDOTOOLD_PID_FILE")
        if kill -0 "$YDO_PID" 2>/dev/null; then
            # ydotoold daemon already running, reuse it
            : # No action needed, already running
        else
            # Stale PID file, clean up and start new
            rm "$YDOTOOLD_PID_FILE"
            ydotoold &
            echo $! > "$YDOTOOLD_PID_FILE"
            sleep 1 # Give it time to fully start and create the virtual device
        fi
    else
        # No PID file, start ydotoold for the first time
        ydotoold &
        echo $! > "$YDOTOOLD_PID_FILE"
        sleep 1 # Give it time to fully start and create the virtual device
    fi

    # Final verification: Check if ydotoold socket is present and valid
    if [ ! -S "$YDO_SOCKET" ]; then
        notify-send -u critical "$NOTIFY_APP Error" "ydotoold socket missing. Autoclicker aborted."
        # Attempt to kill ydotoold if it started but didn't create socket
        if [ -f "$YDOTOOLD_PID_FILE" ]; then
            YDO_PID_TO_KILL=$(cat "$YDOTOOLD_PID_FILE")
            if kill -0 "$YDO_PID_TO_KILL" 2>/dev/null; then
                kill "$YDO_PID_TO_KILL"
                rm "$YDOTOOLD_PID_FILE"
            fi
        fi
        exit 1
    fi

    notify-send -t 2000 "$NOTIFY_APP: ON" "Interval: ${CLICK_INTERVAL_MS}ms"

    # Start the clicking loop in the background
    autoclick_loop "$CLICK_INTERVAL_MS" "$MOUSE_CLICK_CODE" &
    echo $! > "$AUTOCLICK_PID_FILE" # Save the autoclicker loop's PID
fi