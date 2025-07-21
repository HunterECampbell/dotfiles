#!/bin/bash

# Script to set up a dedicated gaming SSD partition on Arch Linux.
# It interactively prompts the user to select a partition, checks its
# filesystem, and offers to format it to ext4 if needed (with data loss warning).
# It then mounts the partition and adds an entry to /etc/fstab for
# automatic mounting on boot.

# --- Color Definitions for better readability ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}--- Starting Dedicated Gaming SSD Setup ---${NC}"

# --- Check for Root Privileges and Elevate if Necessary ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}This script requires root privileges. Attempting to elevate using sudo...${NC}"
    # Use -E to preserve environment, and pass all arguments ($@)
    exec sudo -E "$0" "$@" # Re-execute the script with sudo, preserving environment and arguments
    # The 'exec' command replaces the current shell process, so this script will restart as root.
    # If sudo fails (e.g., incorrect password), the script will terminate.
fi

# From this point onwards, the script is running with root privileges.
# Store the original user who invoked sudo for later use (e.g., chown)
ORIG_USER="${SUDO_USER:-$(logname)}"

MOUNT_POINT="/mnt/gaming_ssd"
GAMING_SSD_DEVICE="" # This will be set by user selection

echo -e "${BLUE}Scanning for available block devices...${NC}"

# Improved jq command to list only partitions, ensuring consistent output fields.
# It iterates through blockdevices and their children, selecting only those of type "part".
LSBLK_OUTPUT=$(lsblk -J -o NAME,SIZE,TYPE,MOUNTPOINTS,MODEL,SERIAL,FSTYPE,UUID | \
  jq -r '.blockdevices[] | (.children[]? // .) | select(.type == "part") | "\(.name) \(.size) \(.mountpoints) \(.fstype) \(.model // "") \(.serial // "") \(.uuid // "")"')

mapfile -t ALL_PARTITIONS <<< "$LSBLK_OUTPUT"

declare -A DEVICE_MAP # This map will store the /dev/name for each numbered selectable option
OS_PARTITIONS=() # Array to hold names of partitions identified as OS/Swap

# First pass: Identify OS/Swap partitions
for PARTITION_INFO in "${ALL_PARTITIONS[@]}"; do
    NAME=$(echo "$PARTITION_INFO" | awk '{print $1}')
    MOUNTPOINTS_RAW=$(echo "$PARTITION_INFO" | awk '{print $3}') # e.g., ["/"] or ["/boot/efi"] or ["/mnt/gaming_ssd"] or null
    FSTYPE=$(echo "$PARTITION_INFO" | awk '{print $4}')

    IS_CRITICAL_OS_PARTITION="false"
    if [ "$MOUNTPOINTS_RAW" != "null" ] && [ -n "$MOUNTPOINTS_RAW" ]; then
        # Check for specific critical OS mount points
        if [[ "$MOUNTPOINTS_RAW" == *"\"/\""* ]] || \
           [[ "$MOUNTPOINTS_RAW" == *"\"/boot\""* ]] || \
           [[ "$MOUNTPOINTS_RAW" == *"\"/boot/efi\""* ]]; then
            IS_CRITICAL_OS_PARTITION="true"
        fi
    fi
    # Check if it's a swap partition
    if [[ "$FSTYPE" == "swap" ]]; then
        IS_CRITICAL_OS_PARTITION="true"
    fi

    if [ "$IS_CRITICAL_OS_PARTITION" == "true" ]; then
        OS_PARTITIONS+=("$NAME")
    fi
done

# --- Build the list of selectable devices for the user ---
SELECTABLE_DEVICES_DISPLAY=() # Stores formatted strings for display
SELECTABLE_DEVICE_COUNT=0

for PARTITION_INFO in "${ALL_PARTITIONS[@]}"; do
    NAME=$(echo "$PARTITION_INFO" | awk '{print $1}')
    SIZE=$(echo "$PARTITION_INFO" | awk '{print $2}')
    MOUNTPOINTS_RAW=$(echo "$PARTITION_INFO" | awk '{print $3}')
    FSTYPE=$(echo "$PARTITION_INFO" | awk '{print $4}')
    MODEL=$(echo "$PARTITION_INFO" | awk '{print $5}')
    SERIAL=$(echo "$PARTITION_INFO" | awk '{print $6}')
    UUID_VAL=$(echo "$PARTITION_INFO" | awk '{print $7}')

    # Filter out loop/zram devices (though jq already targets "part" type)
    if [[ "$NAME" =~ ^(loop|zram) ]]; then
        continue
    fi

    # Determine if it's an OS/Swap partition (these are not selectable for gaming SSD)
    IS_OS_PARTITION="false"
    for os_part in "${OS_PARTITIONS[@]}"; do
        if [[ "$NAME" == "$os_part" ]]; then
            IS_OS_PARTITION="true"
            break
        fi
    done

    if [ "$IS_OS_PARTITION" == "true" ]; then
        continue # Skip OS/Swap partitions from the selectable list
    fi

    # This is a selectable partition
    SELECTABLE_DEVICE_COUNT=$((SELECTABLE_DEVICE_COUNT + 1))
    DEVICE_MAP[$SELECTABLE_DEVICE_COUNT]="/dev/${NAME}"

    DISPLAY_MOUNTPOINTS="Not Mounted"
    if [ "$MOUNTPOINTS_RAW" != "null" ] && [ -n "$MOUNTPOINTS_RAW" ]; then
        CLEAN_MOUNTPOINTS=$(echo "$MOUNTPOINTS_RAW" | sed 's/[\["\]]//g' | sed 's/, / /g' | sed 's/,//g')
        if [ -n "$CLEAN_MOUNTPOINTS" ]; then # Make sure it's not just an empty string after cleaning
            DISPLAY_MOUNTPOINTS="${GREEN}Mounted at: ${CLEAN_MOUNTPOINTS}${NC}"
        fi
    fi

    SELECTABLE_DEVICES_DISPLAY+=("${SELECTABLE_DEVICE_COUNT}: /dev/${NAME} - Size: ${SIZE} - FS: ${FSTYPE:-unknown} - Model: ${MODEL} - Serial: ${SERIAL} - UUID: ${UUID_VAL} - ${DISPLAY_MOUNTPOINTS}")
done

if [ "$SELECTABLE_DEVICE_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No suitable secondary partitions found for gaming SSD setup. Exiting SSD setup.${NC}"
    exit 0 # Exit successfully, no action needed
fi

# --- Safety check: If only one candidate partition is found after filtering, skip. ---
# This prevents accidental formatting if the single candidate is ambiguous or critical.
if [ "$SELECTABLE_DEVICE_COUNT" -eq 1 ]; then
    GAMING_SSD_DEVICE="${SELECTABLE_DEVICE_MAP[1]}" # Get the name of the single candidate
    echo -e "${YELLOW}Only one non-OS/swap candidate partition found for gaming SSD: ${GAMING_SSD_DEVICE}.${NC}"
    echo -e "${YELLOW}For safety, automatic setup is skipped when only one candidate partition is identified.${NC}"
    echo -e "${YELLOW}If you wish to proceed with this partition, please set it up manually.${NC}"
    echo -e "${YELLOW}Consider that this might be a critical data partition or a misidentified OS partition.${NC}"
    exit 0 # Exit successfully, skipping setup
fi

echo -e "${BLUE}Please select the partition for your gaming SSD:${NC}"
echo -e "${YELLOW}DO NOT select partitions marked as '${RED}OS Drive / Swap${YELLOW}' as this could render your system unbootable.${NC}"
echo ""

# Display selectable devices for user selection
for DEVICE_DISPLAY_INFO in "${SELECTABLE_DEVICES_DISPLAY[@]}"; do
    echo -e "${BLUE}${DEVICE_DISPLAY_INFO}${NC}"
done

SELECTED_NUM=""
while true; do
    read -p "Enter the number of the partition you want to use for gaming, or 's' to skip SSD setup: " SELECTED_NUM
    if [[ "$SELECTED_NUM" =~ ^[0-9]+$ ]] && [ "$SELECTED_NUM" -ge 1 ] && [ "$SELECTED_NUM" -le "$SELECTABLE_DEVICE_COUNT" ]; then
        GAMING_SSD_DEVICE="${DEVICE_MAP[$SELECTED_NUM]}"
        echo -e "${BLUE}You selected: ${GAMING_SSD_DEVICE}${NC}"
        break
    elif [[ "$SELECTED_NUM" == "s" || "$SELECTED_NUM" == "S" ]]; then
        echo -e "${YELLOW}Gaming SSD setup skipped by user.${NC}"
        exit 0 # Exit successfully if user explicitly skips
    else
        echo -e "${RED}Invalid selection. Please enter a number between 1 and ${SELECTABLE_DEVICE_COUNT}, or 's' to skip.${NC}"
    fi
done

# Get current filesystem type of the SELECTED device
CURRENT_FS_TYPE=$(blkid -s TYPE -o value "$GAMING_SSD_DEVICE" 2>/dev/null)
GAMING_SSD_UUID_OLD=$(blkid -s UUID -o value "$GAMING_SSD_DEVICE" 2>/dev/null) # Store old UUID for fstab cleanup

if [ -z "$CURRENT_FS_TYPE" ]; then
    echo -e "${RED}Error: No filesystem detected on ${GAMING_SSD_DEVICE}. Cannot proceed with setup.${NC}"
    exit 1
fi

echo -e "${BLUE}Detected filesystem on ${GAMING_SSD_DEVICE}: ${CURRENT_FS_TYPE}${NC}"

PROCEED_FORMAT="no" # Default to no formatting

if [ "$CURRENT_FS_TYPE" = "ext4" ]; then
    echo -e "${GREEN}Filesystem is already ext4. Proceeding with mounting and fstab setup.${NC}"
elif [ "$CURRENT_FS_TYPE" = "crypto_LUKS" ]; then
    echo -e "${RED}WARNING: The detected filesystem (${CURRENT_FS_TYPE}) is an encrypted LUKS volume.${NC}"
    echo -e "${RED}Formatting ${GAMING_SSD_DEVICE} to ext4 will DESTROY the LUKS container and ERASE ALL DATA on it!${NC}"
    echo -e "${RED}If you wish to keep the encryption and its data, DO NOT proceed with formatting.${NC}"
    echo -e "${RED}This script is designed to set up a new, directly mountable ext4 partition specifically for gaming.${NC}"
    read -p "Do you understand and still want to proceed with formatting ${GAMING_SSD_DEVICE} to ext4? (Type 'yes' to confirm, 'no' to skip): " CONFIRM_FORMAT

    if [ "$CONFIRM_FORMAT" = "yes" ]; then
        PROCEED_FORMAT="yes"
        echo -e "${GREEN}Proceeding with formatting ${GAMING_SSD_DEVICE}...${NC}"
    else
        echo -e "${YELLOW}Formatting cancelled by user. Gaming SSD setup skipped (LUKS partition not reformatted).${NC}"
        echo "No SSD will be mounted for gaming via this script. Please manually setup your gaming SSD."
        exit 0 # Exit successfully if user declines formatting
    fi
else # For any other filesystem type that is not ext4 or crypto_LUKS
    echo -e "${RED}WARNING: The detected filesystem (${CURRENT_FS_TYPE}) is NOT ext4.${NC}"
    echo -e "${RED}Formatting ${GAMING_SSD_DEVICE} to ext4 will ERASE ALL DATA on it!${NC}"
    read -p "Do you want to proceed with formatting ${GAMING_SSD_DEVICE} to ext4? (Type 'yes' to confirm, 'no' to skip): " CONFIRM_FORMAT

    if [ "$CONFIRM_FORMAT" = "yes" ]; then
        PROCEED_FORMAT="yes"
        echo -e "${GREEN}Proceeding with formatting ${GAMING_SSD_DEVICE}...${NC}"
    else
        echo -e "${YELLOW}Formatting cancelled by user. Gaming SSD setup skipped (partition not reformatted).${NC}"
        echo "No SSD will be mounted for gaming via this script. Please manually setup your gaming SSD."
        exit 0 # Exit successfully if user declines formatting
    fi
fi

# --- Core SSD Setup Steps ---
# Unmount the partition if it's currently mounted (could be mounted from fstab, or manually)
echo -e "${YELLOW}Attempting to unmount ${GAMING_SSD_DEVICE} if currently mounted...${NC}"
if mountpoint -q "$MOUNT_POINT"; then
    sudo umount "$MOUNT_POINT" &>/dev/null
fi
# Also try unmounting directly if it's mounted elsewhere
MOUNTED_AT=$(lsblk -no MOUNTPOINTS "$GAMING_SSD_DEVICE" | awk 'NR==2 {print $1}')
if [ -n "$MOUNTED_AT" ] && [ "$MOUNTED_AT" != "null" ]; then
    echo -e "${YELLOW}Unmounting ${GAMING_SSD_DEVICE} from ${MOUNTED_AT}...${NC}"
    sudo umount "$MOUNTED_AT" || { echo -e "${RED}Error: Failed to unmount ${GAMING_SSD_DEVICE} from ${MOUNTED_AT}. Please ensure nothing is using it.${NC}"; exit 1; }
fi
echo -e "${GREEN}Unmount attempt complete.${NC}"


echo -e "${GREEN}Creating ${MOUNT_POINT} directory...${NC}"
sudo mkdir -p "$MOUNT_POINT" || { echo -e "${RED}Error: Failed to create mount point directory: ${MOUNT_POINT}.${NC}"; exit 1; }

if [ "$PROCEED_FORMAT" = "yes" ]; then
    echo -e "${GREEN}Formatting ${GAMING_SSD_DEVICE} to ext4...${NC}"
    sudo mkfs.ext4 -F "$GAMING_SSD_DEVICE" || { echo -e "${RED}Error: Failed to format ${GAMING_SSD_DEVICE}.${NC}"; exit 1; }
    # -F forces mkfs.ext4 to overwrite an existing filesystem
fi

echo -e "${GREEN}Mounting ${GAMING_SSD_DEVICE} to ${MOUNT_POINT}...${NC}"
sudo mount "$GAMING_SSD_DEVICE" "$MOUNT_POINT" || { echo -e "${RED}Error: Failed to mount ${GAMING_SSD_DEVICE}.${NC}"; exit 1; }

echo -e "${GREEN}Setting permissions for ${ORIG_USER} on ${MOUNT_POINT}...${NC}"
sudo chown "${ORIG_USER}:${ORIG_USER}" "$MOUNT_POINT" || { echo -e "${RED}Error: Failed to set permissions on ${MOUNT_POINT}.${NC}"; exit 1; }

echo -e "${GREEN}Adding/Updating entry in /etc/fstab...${NC}"
NEW_UUID=$(sudo blkid -s UUID -o value "$GAMING_SSD_DEVICE")
if [ -z "$NEW_UUID" ]; then
    echo -e "${RED}Error: Failed to get UUID for ${GAMING_SSD_DEVICE}. Please add to /etc/fstab manually.${NC}"
    exit 1
else
    # Remove any existing line for this mount point or device or old UUID
    sudo sed -i "\@${MOUNT_POINT}@d" /etc/fstab
    sudo sed -i "\@${GAMING_SSD_DEVICE}@d" /etc/fstab # Remove entries by device path
    if [ -n "$GAMING_SSD_UUID_OLD" ]; then # Only remove if old UUID existed
        sudo sed -i "\@${GAMING_SSD_UUID_OLD}@d" /etc/fstab
    fi
    sudo sed -i "\@${NEW_UUID}@d" /etc/fstab # Remove new UUID entry if somehow already there

    echo "UUID=${NEW_UUID}    ${MOUNT_POINT}    ext4    defaults,noatime    0 2" | sudo tee -a /etc/fstab > /dev/null
    echo -e "${GREEN}fstab entry added. Testing mount...${NC}"

    # Test the fstab entry by unmounting and then 'mount -a'
    sudo umount "$MOUNT_POINT" || echo -e "${YELLOW}Warning: Could not unmount ${MOUNT_POINT} for fstab test, but attempting mount -a anyway.${NC}"
    sudo mount -a || { echo -e "${RED}Error: fstab entry test failed. Please check /etc/fstab manually.${NC}"; exit 1; }
    echo -e "${GREEN}Gaming SSD setup and mounted successfully.${NC}"
fi

echo -e "${GREEN}--- Dedicated Gaming SSD Setup Complete ---${NC}"
exit 0