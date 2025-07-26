#!/bin/bash

# Script to add 'nvidia-drm.modeset=1' to the latest systemd-boot kernel entry.
# This script will:
# - Check if the parameter is already active in the running kernel.
# - Find the latest non-fallback kernel entry in /boot/loader/entries/.
# - Add 'nvidia-drm.modeset=1' to the 'options' line of that entry if not present.
#
# IMPORTANT: This script MUST be run with sudo:
# sudo /path/to/your_script.sh

# --- Color Definitions for better readability ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting script to add nvidia-drm.modeset=1 to systemd-boot entry...${NC}"

# --- 1. Check if the parameter is already active ---
echo -e "${BLUE}Checking current kernel command line...${NC}"
CURRENT_CMDLINE=$(cat /proc/cmdline)

if echo "$CURRENT_CMDLINE" | grep -q "nvidia-drm.modeset=1"; then
    echo -e "${GREEN}nvidia-drm.modeset=1 is already active in your current kernel command line.${NC}"
    echo -e "${GREEN}No changes needed. Please reboot if you just applied changes and haven't rebooted yet.${NC}"
    exit 0
else
    echo -e "${YELLOW}nvidia-drm.modeset=1 is NOT active in your current kernel command line.${NC}"
fi

# --- 2. Find the target systemd-boot entry file ---
BOOT_ENTRIES_DIR="/boot/loader/entries"

echo -e "${BLUE}Searching for systemd-boot entries in ${BOOT_ENTRIES_DIR}...${NC}"

if [ ! -d "$BOOT_ENTRIES_DIR" ]; then
    echo -e "${RED}Error: ${BOOT_ENTRIES_DIR} not found. This script is for systemd-boot setups where /boot is the EFI System Partition.${NC}"
    echo -e "${RED}Please ensure your system uses systemd-boot and that /boot is correctly mounted.${NC}"
    exit 1
fi

# Find the latest non-fallback .conf file.
# Sort by modification time and pick the newest that does NOT contain 'fallback'.
TARGET_ENTRY_FILE=$(ls -t "$BOOT_ENTRIES_DIR"/*.conf | grep -v "fallback" | head -n 1)

if [ -z "$TARGET_ENTRY_FILE" ]; then
    echo -e "${RED}Error: No suitable systemd-boot entry file found in ${BOOT_ENTRIES_DIR}.${NC}"
    echo -e "${RED}Ensure your main Arch Linux entry exists and is not named with 'fallback'.${NC}"
    exit 1
fi

echo -e "${GREEN}Identified target boot entry file: ${TARGET_ENTRY_FILE}${NC}"

# --- 3. Add nvidia-drm.modeset=1 to the options line if not present ---
echo -e "${BLUE}Checking content of ${TARGET_ENTRY_FILE}...${NC}"

# Read the entire file content
FILE_CONTENT=$(<"$TARGET_ENTRY_FILE")

# Check if 'nvidia-drm.modeset=1' is already in the options line of the file
if echo "$FILE_CONTENT" | grep -q "options .*nvidia-drm.modeset=1"; then
    echo -e "${GREEN}nvidia-drm.modeset=1 is already present in the options line of ${TARGET_ENTRY_FILE}.${NC}"
else
    echo -e "${YELLOW}Adding nvidia-drm.modeset=1 to the options line in ${TARGET_ENTRY_FILE}...${NC}"

    # Use sed to append the parameter to the 'options' line
    # The 'I' flag makes it case-insensitive for 'options', though it's typically lowercase.
    # The 's/$/ nvidia-drm.modeset=1/' adds it at the end of the line.
    sudo sed -i 's/^\(options .*\)$/\1 nvidia-drm.modeset=1/' "$TARGET_ENTRY_FILE"

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to modify ${TARGET_ENTRY_FILE}. Please check permissions or file integrity.${NC}"
        exit 1
    else
        echo -e "${GREEN}Successfully added nvidia-drm.modeset=1 to ${TARGET_ENTRY_FILE}.${NC}"
    fi
fi

echo -e "\n--- Script Summary ---"
echo -e "${GREEN}Script finished!${NC}"
echo -e "${YELLOW}Important next step:${NC}"
echo -e "${YELLOW}You MUST reboot your system for the 'nvidia-drm.modeset=1' kernel parameter to take effect.${NC}"
echo -e "${YELLOW}After rebooting, run 'cat /proc/cmdline' to confirm it's present.${NC}"
echo -e "----------------------"

exit 0