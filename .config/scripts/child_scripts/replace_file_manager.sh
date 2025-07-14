#!/bin/bash

# Script to replace Dolphin file manager with Nautilus (GNOME Files).
# This script will:
# - Install Nautilus.
# - Uninstall Dolphin and its unneeded dependencies.
# - Set Nautilus as the default file manager using xdg-mime.
#
# IMPORTANT: This script is designed to be run with sudo:
# sudo ~/.config/scripts/child_scripts/replace_file_manager.sh

# --- Color Definitions for better readability ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting file manager replacement: Dolphin to Nautilus...${NC}"

# --- 1. Install Nautilus ---
echo -e "${GREEN}Checking if Nautilus is installed...${NC}"
if ! command -v nautilus &> /dev/null; then
    echo -e "${YELLOW}Nautilus not found. Attempting to install Nautilus...${NC}"
    # --noconfirm is used as this script assumes it's part of a master setup script
    sudo pacman -S nautilus --noconfirm
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to install Nautilus. Please check your package manager and internet connection.${NC}"
        exit 1
    else
        echo -e "${GREEN}Nautilus installed successfully.${NC}"
    fi
else
    echo -e "${GREEN}Nautilus is already installed.${NC}"
fi

# --- 2. Uninstall Dolphin ---
echo -e "${GREEN}Checking if Dolphin is installed...${NC}"
if command -v dolphin &> /dev/null; then
    echo -e "${YELLOW}Dolphin found. Attempting to uninstall Dolphin and its unneeded dependencies...${NC}"
    # -Rns: Remove package, its configuration files, and unneeded dependencies
    sudo pacman -Rns dolphin --noconfirm
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to uninstall Dolphin. Please check for issues and try manually.${NC}"
        # Do not exit here, as Nautilus might still be installed and xdg-mime can be set.
    else
        echo -e "${GREEN}Dolphin uninstalled successfully.${NC}"
    fi
else
    echo -e "${GREEN}Dolphin is not installed. Skipping uninstallation.${NC}"
fi

# --- 3. Ensure xdg-utils (for xdg-mime) is installed ---
echo -e "${GREEN}Checking if xdg-utils (providing xdg-mime) is installed...${NC}"
if ! command -v xdg-mime &> /dev/null; then
    echo -e "${YELLOW}xdg-mime not found. Attempting to install xdg-utils...${NC}"
    sudo pacman -S xdg-utils --noconfirm
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to install xdg-utils. Cannot set default file manager.${NC}"
        exit 1
    else
        echo -e "${GREEN}xdg-utils installed successfully.${NC}"
    fi
else
    echo -e "${GREEN}xdg-utils is already installed.${NC}"
fi

# --- 4. Set Nautilus as the default file manager using xdg-mime ---
echo -e "${GREEN}Setting Nautilus as the default file manager for directories...${NC}"
# Note: xdg-mime is typically run as the user, not root.
# We use sudo -u "$SUDO_USER" to execute it as the original user who invoked sudo.
# ${SUDO_USER:-$(logname)} ensures it works even if SUDO_USER is not set (e.g., direct root login)
sudo -u "${SUDO_USER:-$(logname)}" xdg-mime default nautilus.desktop inode/directory application/x-directory
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to set Nautilus as default using xdg-mime. You may need to do this manually.${NC}"
else
    echo -e "${GREEN}Nautilus set as default file manager for directories.${NC}"
fi

echo -e "\n--- File Manager Replacement Summary ---"
echo -e "${GREEN}Script finished!${NC}"
echo -e "${YELLOW}Important next steps:${NC}"
echo -e "${YELLOW}1. If you have any Hyprland keybindings that launched Dolphin, remember to update them to 'nautilus'.${NC}"
echo -e "   Example: Change 'bind = \$mainMod, F, exec, dolphin' to 'bind = \$mainMod, F, exec, nautilus' in your hyprland.conf."
echo -e "${YELLOW}2. Reload your Hyprland configuration (hyprctl reload) or restart your session for changes to take full effect.${NC}"
echo -e "----------------------------------------"

exit 0
