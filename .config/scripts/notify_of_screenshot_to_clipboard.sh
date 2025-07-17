#!/bin/bash

# Script to take a screenshot of a selected area and copy it to the clipboard,
# then send a notification.

# Define notification title and messages
NOTIFY_TITLE="Screenshot Taken"
SUCCESS_MSG="Selected area copied to clipboard."
ERROR_MSG="Failed to take screenshot."

# --- Main Logic ---

# Execute grimblast to copy a selected area to the clipboard.
# The `grimblast copy area` command will wait for the user to select an area.
# We'll check its exit status to determine success or failure.
if grimblast copy area; then
    # If grimblast command was successful (exit status 0)
    notify-send "$NOTIFY_TITLE" "$SUCCESS_MSG"
else
    # If grimblast command failed (non-zero exit status, e.g., user cancelled selection)
    notify-send --urgency=critical "$NOTIFY_TITLE" "$ERROR_MSG"
fi

exit 0
