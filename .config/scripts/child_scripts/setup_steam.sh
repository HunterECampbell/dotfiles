#!/bin/bash

# Script to install Steam and essential gaming dependencies on Arch Linux.
# This script is tailored for NVIDIA users and assumes 'yay' is configured.
#
# This script will prompt for your sudo password for necessary operations.

# --- Color Definitions for better readability ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Steam and gaming dependencies installation script...${NC}"

# --- 1. Check for Root Privileges and Elevate if Necessary ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}This script requires root privileges. Attempting to elevate using sudo...${NC}"
    exec sudo -E "$0" "$@" # Re-execute the script with sudo, preserving environment and arguments
    # The 'exec' command replaces the current shell process, so this script will restart as root.
    # If sudo fails (e.g., incorrect password), the script will terminate.
fi

# From this point onwards, the script is running with root privileges.

# --- 2. Check if Steam is already installed ---
if command -v steam &> /dev/null; then
    echo -e "${GREEN}Steam is already installed.${NC}"
    echo -e "${YELLOW}Skipping Steam installation and proceeding with dependency checks.${NC}"
else
    echo -e "${YELLOW}Steam is not detected. Proceeding with installation.${NC}"
fi

# --- 3. Enable Multilib Repository ---
echo -e "${YELLOW}Enabling 'multilib' repository in /etc/pacman.conf...${NC}"
# Uncomment the [multilib] section
sed -i '/\[multilib\]/s/^#//' /etc/pacman.conf
# Uncomment the Include line below [multilib]
sed -i '/\[multilib\]/{n;s/^#//}' /etc/pacman.conf

# Verify multilib is uncommented
if grep -q "^\[multilib\]" /etc/pacman.conf && grep -q "Include = /etc/pacman.d/mirrorlist" /etc/pacman.conf; then
    echo -e "${GREEN}'multilib' repository enabled successfully.${NC}"
else
    echo -e "${RED}Warning: Failed to uncomment 'multilib' in /etc/pacman.conf.${NC}"
    echo -e "${RED}Please manually check and uncomment the '[multilib]' section and its 'Include' line.${NC}"
    echo -e "${RED}Example:${NC}"
    echo -e "${RED}[multilib]${NC}"
    echo -e "${RED}Include = /etc/pacman.d/mirrorlist${NC}"
    read -p "Press Enter to continue after manual check/fix of /etc/pacman.conf..."
fi

echo -e "${GREEN}Refreshing pacman database after 'multilib' changes...${NC}"
pacman -Syy
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to refresh pacman database. Exiting.${NC}"
    exit 1
else
    echo -e "${GREEN}Pacman database refreshed.${NC}"
fi

# --- 4. Install Steam and NVIDIA 32-bit Compatibility Libraries ---
echo -e "${YELLOW}Installing Steam and 'lib32-nvidia-utils' (NVIDIA 32-bit drivers).${NC}"
echo -e "${YELLOW}!!! IMPORTANT: You MAY be prompted to select a repository for 'lib32-nvidia-utils' (e.g., 'multilib').${NC}"
echo -e "${YELLOW}!!! Please read the prompt carefully and type the correct number (often '2') and press Enter.${NC}"
echo -e "${YELLOW}Example prompt: 'Enter a number (default=1):'${NC}"

# We do NOT use --noconfirm here to allow for interactive repository selection if needed (less common for steam itself)
echo -e "${YELLOW}Installing Steam...${NC}"
pacman -S steam
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to install Steam.${NC}"
    echo -e "${RED}Please review the output above for errors and try installing it manually.${NC}"
    exit 1
else
    echo -e "${GREEN}Steam installed successfully.${NC}"
fi

# --- 5. Install Additional Recommended Gaming Packages ---
echo -e "${GREEN}Installing 'wine-staging' for Proton compatibility...${NC}"
pacman -S --noconfirm --needed wine-staging
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Warning: Failed to install 'wine-staging'. Some games may not run correctly.${NC}"
fi

echo -e "${GREEN}Installing 'winetricks' for Wine configuration...${NC}"
pacman -S --noconfirm --needed winetricks
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Warning: Failed to install 'winetricks'. You may need it for specific game dependencies.${NC}"
fi

echo -e "${GREEN}Installing Vulkan ICD Loaders...${NC}"
pacman -S --noconfirm --needed vulkan-icd-loader lib32-vulkan-icd-loader
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Warning: Failed to install Vulkan ICD Loaders. Vulkan-based games may not run.${NC}"
fi

echo -e "${GREEN}Installing NVIDIA Vulkan drivers and utilities...${NC}"
pacman -S --noconfirm --needed nvidia-utils lib32-nvidia-utils
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Warning: Failed to install NVIDIA Vulkan drivers. Performance issues may occur.${NC}"
fi

echo -e "${GREEN}Installing Vulkan Mesa layers...${NC}"
pacman -S --noconfirm --needed vulkan-mesa-layers lib32-vulkan-mesa-layers
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Warning: Failed to install Vulkan Mesa layers. This might affect some Vulkan applications.${NC}"
fi

echo -e "${GREEN}All additional gaming packages installation attempts completed.${NC}"

# --- 6. Install Proton-GE-Custom via Yay ---
echo -e "${GREEN}Installing 'proton-ge-custom' via 'yay' (AUR).${NC}"
# Run yay as the user who invoked sudo, not as root, for AUR builds
sudo -u "${SUDO_USER:-$(logname)}" yay -S --noconfirm proton-ge-custom
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Warning: Failed to install 'proton-ge-custom'.${NC}"
    echo -e "${YELLOW}You may need to install it manually later using 'yay -S proton-ge-custom'.${NC}"
else
    echo -e "${GREEN}'proton-ge-custom' installed successfully.${NC}"
fi

# --- Final Status and Instructions ---
echo -e "\n--- Steam Installation Summary ---"
echo -e "${GREEN}Installation script finished!${NC}"
echo -e "${YELLOW}1. If you were prompted for repository selections during installation, ensure you made the correct choices.${NC}"
echo -e "${YELLOW}2. You can now launch Steam by typing 'steam' in your terminal or from your application launcher.${NC}"
echo -e "${YELLOW}3. Remember to configure Steam Play within Steam settings if needed (Steam -> Settings -> Steam Play).${NC}"
echo -e "${YELLOW}4. IMPORTANT: Ensure you have added the necessary window rules to your hyprland.conf for Steam's floating windows. (This should already be done.)${NC}"
echo -e "   Example rules (add to your hyprland.conf if not already there):"
echo -e "   windowrulev2 = float, class:^(Steam)$"
echo -e "   windowrulev2 = float, class:^(Steam)$, title:^(Steam - News)$"
echo -e "   windowrulev2 = float, class:^(Steam)$, title:^(Friends List)$"
echo -e "   windowrulev2 = float, class:^(Steam)$, title:^(Steam - Big Picture Mode)$"
echo -e "   # You might need more rules for stubborn Proton games (use 'hyprctl clients' to find titles)"
echo -e "----------------------------------"

exit 0
