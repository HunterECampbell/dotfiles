# #!/bin/bash

# # Script to enable Kernel Mode Setting (KMS) for NVIDIA drivers on Arch Linux.
# # This script will:
# # - Self-elevate to root privileges if not already running as such.
# # - Add necessary NVIDIA modules to /etc/mkinitcpio.conf.
# # - Create/update /etc/modprobe.d/nvidia.conf to enable modeset and fbdev.
# # - Rebuild the initramfs.
# # - Prompt the user to reboot the system.
# #
# # This script will attempt to elevate itself to sudo if not run as root.

# # --- Color Definitions for better readability ---
# GREEN='\033[0;32m'
# YELLOW='\033[1;33m'
# RED='\033[0;31m'
# BLUE='\033[0;34m'
# NC='\033[0m' # No Color

# echo -e "${YELLOW}Starting script to enable NVIDIA Kernel Mode Setting (KMS)...${NC}"

# # --- 0. Check for root privileges and self-elevate if necessary ---
# if [ "$EUID" -ne 0 ]; then
#     echo -e "${YELLOW}Attempting to elevate privileges with sudo...${NC}"
#     # Re-execute the script with sudo, preserving all arguments
#     exec sudo "$0" "$@"
#     # The script will exit here if sudo fails or if it successfully re-executes.
# fi

# # If we reach here, the script is running with root privileges.
# echo -e "${GREEN}Running with root privileges.${NC}"

# REBOOT_REQUIRED=false

# # --- 1. Modify /etc/mkinitcpio.conf ---
# MKINITCPIO_CONF="/etc/mkinitcpio.conf"
# REQUIRED_MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"

# echo -e "${BLUE}Checking and updating ${MKINITCPIO_CONF}...${NC}"

# if [ ! -f "$MKINITCPIO_CONF" ]; then
#     echo -e "${RED}Error: ${MKINITCPIO_CONF} not found. This file is essential for initramfs configuration.${NC}"
#     exit 1
# fi

# # Check if all required modules are already in the MODULES array
# ALL_MODULES_PRESENT=true
# for module in $REQUIRED_MODULES; do
#     if ! grep -q "MODULES=(.*$module.*)" "$MKINITCPIO_CONF"; then
#         ALL_MODULES_PRESENT=false
#         break
#     fi
# done

# if "$ALL_MODULES_PRESENT"; then
#     echo -e "${GREEN}All required NVIDIA modules are already present in ${MKINITCPIO_CONF}.${NC}"
# else
#     echo -e "${YELLOW}Adding NVIDIA modules to MODULES array in ${MKINITCPIO_CONF}...${NC}"
#     # Use sed to add modules if not present, ensuring idempotency
#     # This sed command appends modules only if they are not already there.
#     # It finds the MODULES line and then uses a series of substitutions.
#     # The 's/ /\ /g' is a trick to escape spaces for sed's s command.
#     sed -i "/^MODULES=(/ s/^\(MODULES=(.*\))$/\1 ${REQUIRED_MODULES// / }/" "$MKINITCPIO_CONF"

#     # A more robust check if modules were actually added or if they were already there but not in the exact order
#     # This check is simpler: just verify if the line now contains all of them.
#     if grep -q "MODULES=(.*nvidia.*nvidia_modeset.*nvidia_uvm.*nvidia_drm.*)" "$MKINITCPIO_CONF"; then
#         echo -e "${GREEN}Successfully updated ${MKINITCPIO_CONF}.${NC}"
#         REBOOT_REQUIRED=true
#     else
#         echo -e "${RED}Warning: Failed to confirm all modules were added to ${MKINITCPIO_CONF}. Please check manually.${NC}"
#     fi
# fi

# # --- 2. Create and edit /etc/modprobe.d/nvidia.conf ---
# MODPROBE_DIR="/etc/modprobe.d"
# NVIDIA_CONF="${MODPROBE_DIR}/nvidia.conf"
# NVIDIA_OPTIONS="options nvidia_drm modeset=1 fbdev=1"

# echo -e "${BLUE}Checking and updating ${NVIDIA_CONF}...${NC}"

# if [ ! -d "$MODPROBE_DIR" ]; then
#     echo -e "${RED}Error: ${MODPROBE_DIR} not found. This directory is needed for modprobe configurations.${NC}"
#     exit 1
# fi

# if [ -f "$NVIDIA_CONF" ]; then
#     if grep -qF "$NVIDIA_OPTIONS" "$NVIDIA_CONF"; then
#         echo -e "${GREEN}The line '${NVIDIA_OPTIONS}' is already present in ${NVIDIA_CONF}.${NC}"
#     else
#         echo -e "${YELLOW}Updating ${NVIDIA_CONF} with '${NVIDIA_OPTIONS}'...${NC}"
#         # Remove any existing options nvidia_drm line and add the new one
#         sed -i "/^options nvidia_drm/d" "$NVIDIA_CONF"
#         echo "$NVIDIA_OPTIONS" | tee -a "$NVIDIA_CONF" > /dev/null
#         if [ $? -eq 0 ]; then
#             echo -e "${GREEN}Successfully updated ${NVIDIA_CONF}.${NC}"
#             REBOOT_REQUIRED=true
#         else
#             echo -e "${RED}Error: Failed to update ${NVIDIA_CONF}. Please check permissions.${NC}"
#         fi
#     fi
# else
#     echo -e "${YELLOW}Creating ${NVIDIA_CONF} with '${NVIDIA_OPTIONS}'...${NC}"
#     echo "$NVIDIA_OPTIONS" | tee "$NVIDIA_CONF" > /dev/null
#     if [ $? -eq 0 ]; then
#         echo -e "${GREEN}Successfully created ${NVIDIA_CONF}.${NC}"
#         REBOOT_REQUIRED=true
#     else
#         echo -e "${RED}Error: Failed to create ${NVIDIA_CONF}. Please check permissions.${NC}"
#     fi
# fi

# # --- 3. Rebuild the initramfs ---
# echo -e "${BLUE}Rebuilding initramfs with mkinitcpio -P...${NC}"
# # Redirect standard input from /dev/null to ensure non-interactive operation
# if mkinitcpio -P < /dev/null; then # <--- ADDED '< /dev/null' HERE
#     echo -e "${GREEN}Initramfs rebuild successful!${NC}"
#     REBOOT_REQUIRED=true # Always suggest reboot after initramfs rebuild
# else
#     echo -e "${RED}Error: Initramfs rebuild failed. Please check the output above for errors.${NC}"
#     exit 1
# fi

# echo -e "\n--- Script Summary ---"
# echo -e "${GREEN}NVIDIA Kernel Mode Setting script finished!${NC}"

# if "$REBOOT_REQUIRED"; then
#     echo -e "${YELLOW}Important next step:${NC}"
#     echo -e "${YELLOW}You MUST reboot your system for the changes to take effect.${NC}"
#     echo -e "${YELLOW}Run the following command to reboot:${NC}"
#     echo -e "${BLUE}sudo reboot${NC}"
# else
#     echo -e "${GREEN}No changes were necessary as your system appears to be already configured.${NC}"
#     echo -e "${YELLOW}If you have made recent changes and haven't rebooted, please do so now:${NC}"
#     echo -e "${BLUE}sudo reboot${NC}"
# fi

# echo -e "----------------------"

# exit 0
