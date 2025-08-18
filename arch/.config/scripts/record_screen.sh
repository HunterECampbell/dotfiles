#!/bin/bash

# Define output directory for recordings
OUTPUT_DIR="$HOME/Videos"
mkdir -p "$OUTPUT_DIR" # Ensure the directory exists

# Define filename with current date and time
FILENAME="screencast_$(date +%Y%m%d_%H%M%S).mp4"
FULL_PATH="$OUTPUT_DIR/$FILENAME"

# Check if wf-recorder is already running
if pgrep -x "wf-recorder" > /dev/null; then
    # If running, stop it
    pkill -INT -x wf-recorder
    notify-send "Screen Recording Stopped" "Saved to: $FULL_PATH"
else
    # If not running, start it

    # Start recording a selected region
    # Use -f "$FULL_PATH" $AUDIO_ARGS -c libx264 -x yuv420p for region with audio
    # Use -f "$FULL_PATH" $AUDIO_ARGS -c libx264 -x yuv420p for full screen with audio

    # We'll use region selection here by default, as it's common.
    # For full screen, change "-g "$(slurp)"" to nothing.
    wf-recorder -g "$(slurp)" $AUDIO_ARGS -f "$FULL_PATH" -c libx264 -x yuv420p & # & runs in background

    # -c libx264 -x yuv420p are common FFmpeg options for broader compatibility
    # If you have specific hardware encoders (like vaapi for Intel/AMD), you can use them:
    # -c hevc_vaapi -x vaapi_vpp

    # Send notification
    notify-send "Screen Recording Started" "Select region. Press your hotkey again to stop."
fi