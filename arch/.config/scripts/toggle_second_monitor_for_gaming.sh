#!/bin/bash

# Configuration file path
HYPRLAND_CONF="$HOME/.config/hypr/hyprland.conf"

# The two monitor configuration lines
NORMAL_MONITOR_CONFIG="monitor=,preferred,-1600x175,auto"
GAMING_MONITOR_CONFIG="monitor=,preferred,-1600x17500,auto"

# Function to set gaming mode
set_gaming_mode() {
    echo "Switching to gaming monitor configuration..."
    # Comment out the normal monitor config
    sed -i "s/^${NORMAL_MONITOR_CONFIG}/# ${NORMAL_MONITOR_CONFIG}/" "$HYPRLAND_CONF"
    # Uncomment the gaming one
    sed -i "s/^# ${GAMING_MONITOR_CONFIG}/${GAMING_MONITOR_CONFIG}/" "$HYPRLAND_CONF"
    hyprctl reload
}

# Function to restore normal mode
restore_normal_mode() {
    echo "Restoring normal monitor configuration..."
    # Uncomment the normal monitor config
    sed -i "s/^# ${NORMAL_MONITOR_CONFIG}/${NORMAL_MONITOR_CONFIG}/" "$HYPRLAND_CONF"
    # Comment out the gaming one
    sed -i "s/^${GAMING_MONITOR_CONFIG}/# ${GAMING_MONITOR_CONFIG}/" "$HYPRLAND_CONF"
    hyprctl reload
}

# Ensure the script restores the configuration even if the game crashes
trap restore_normal_mode EXIT

# Call the function to set gaming mode
set_gaming_mode

# Run the game using the command passed to the script
echo "Starting game..."
"$@"

# The 'restore_normal_mode' function will be called automatically on exit