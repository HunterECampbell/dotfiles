#!/usr/bin/env python3

import json
import os
import sys

# Path to a file where you can manually set the unread message count
# Create this file and put a number in it, e.g., "5"
COUNT_FILE = os.path.expanduser("~/.cache/slack_unread_count")

# Slack icon (Nerd Font)
SLACK_ICON = "󰒱" # nf-md-slack

def get_unread_count():
    """
    Simulates getting the unread message count.
    In a real scenario, this would involve Slack API calls.
    Reads the count from a file for demonstration.
    """
    try:
        with open(COUNT_FILE, 'r') as f:
            count_str = f.read().strip()
            count = int(count_str)
            return max(0, count) # Ensure count is not negative
    except (FileNotFoundError, ValueError):
        return 0 # Default to 0 if file not found or content is invalid

def main():
    unread_count = get_unread_count()

    if unread_count > 0:
        # Format the output as JSON for Waybar
        # Use Pango markup to wrap the icon and count in spans with distinct styling attributes.
        # Note: Pango markup does not support 'class' attributes for CSS.
        # We'll use direct attributes like 'foreground', 'background', 'size', 'weight'.
        output = {
            "text": f"<span size='105%'>{SLACK_ICON}</span>&#x2009;<span size='75%' rise='1250'>{unread_count}</span>",
            "tooltip": f"You have {unread_count} unread messages in Slack.",
            "class": "has-messages" # This class is for the module container, not internal spans
        }
        print(json.dumps(output))
    else:
        # If count is 0, print an empty string to hide the module
        print("")

if __name__ == "__main__":
    main()
