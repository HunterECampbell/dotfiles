#!/bin/bash

# This script performs post-setup configuration, enabling services,
# and installing user-level tools that should run after all other
# foundational setup scripts are complete.
#
# It is called by the master script: run_setup_scripts.sh
#
# The script is idempotent and can be re-run safely.

# --- Color Definitions for better readability ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting post-setup script...${NC}"

# --- Sudo Elevation Check ---
# Check if the script is running with root privileges (EUID 0).
# If not, re-execute itself with sudo.
if [[ "$EUID" -ne 0 ]]; then
  echo "This script requires elevated privileges. Attempting to re-run with sudo..."
  # Preserve arguments when re-running with sudo
  exec sudo bash "$0" "$@"
fi

# Determine the target user and their home directory.
TARGET_USER="${SUDO_USER:-$(whoami)}"
TARGET_HOME="/home/$TARGET_USER"
SETUP_TYPE="$1" # Capture the setup type passed from the master script

# Function to prompt user for setup type if not provided
prompt_for_setup_type() {
  local choice=""
  while true; do
    echo "No setup type provided as argument. Please choose an option for script execution:"
    echo "  1) Home"
    echo "  2) Work"
    echo "3) All (Home + Work)"
    echo "  4) EXIT (Do not run any setup scripts)"
    read -p "Enter your choice (1, 2, 3, or 4): " choice

    case "$choice" in
      1) SETUP_TYPE="home"; break ;;
      2) SETUP_TYPE="work"; break ;;
      3) SETUP_TYPE="all"; break ;;
      4) echo "Exiting script as requested."; exit 0 ;;
      *) echo "Invalid choice. Please enter 1, 2, 3, or 4." ;;
    esac
  done
}

# Check if the initial SETUP_TYPE is valid. If not, prompt.
if [[ -z "$SETUP_TYPE" ]] || [[ "$SETUP_TYPE" != "home" && "$SETUP_TYPE" != "work" && "$SETUP_TYPE" != "all" ]]; then
  if [[ -n "$SETUP_TYPE" ]]; then # If an invalid argument was given (not just empty)
    echo "Invalid setup type '$SETUP_TYPE' provided as argument. Falling back to interactive choice."
  fi
  prompt_for_setup_type
fi

echo "Target user for operations: $TARGET_USER"
echo "Selected setup type: $(echo "$SETUP_TYPE" | tr '[:lower:]' '[:upper:]')"
echo "---------------------------------------------------"

# Array to store failed steps
declare -a FAILED_STEPS=()

# --- System-level services common to all setups (requires sudo) ---
_manage_common_services() {
    echo -e "${BLUE}Managing common system-level services...${NC}"

    # Enable and start NetworkManager
    echo -e "${YELLOW}  Enabling and starting NetworkManager.service...${NC}"
    if systemctl enable --now NetworkManager.service; then
        echo -e "${GREEN}  NetworkManager.service enabled and started.${NC}"
    else
        echo -e "${RED}  Error enabling/starting NetworkManager.service.${NC}"
        FAILED_STEPS+=("NetworkManager Service")
    fi

    # Enable and start vpnagentd (for Cisco AnyConnect VPN)
    echo -e "${YELLOW}  Enabling and starting vpnagentd.service...${NC}"
    if systemctl enable --now vpnagentd.service; then
        echo -e "${GREEN}  vpnagentd.service enabled and started.${NC}"
    else
        echo -e "${RED}  Error enabling/starting vpnagentd.service.${NC}"
        FAILED_STEPS+=("VPN Agent Service")
    fi

    # Check status of vpnagentd
    echo -e "${YELLOW}  Checking status of vpnagentd.service...${NC}"
    systemctl status vpnagentd.service --no-pager || FAILED_STEPS+=("VPN Agent Status Check")
    echo "---------------------------------------------------"
}

# --- Work-specific configurations (requires sudo) ---
_manage_work_services() {
    echo -e "${BLUE}Managing work-specific services...${NC}"
    # Start and enable Docker
    echo -e "${YELLOW}  Enabling and starting docker.service...${NC}"
    if systemctl enable --now docker.service; then
        echo -e "${GREEN}  docker.service enabled and started.${NC}"
    else
        echo -e "${RED}  Error enabling/starting docker.service.${NC}"
        FAILED_STEPS+=("Docker Service")
    fi

    # Add the current user to the 'docker' group
    echo -e "${YELLOW}  Adding user '$TARGET_USER' to the 'docker' group...${NC}"
    if usermod -aG docker "$TARGET_USER"; then
        echo -e "${GREEN}  User '$TARGET_USER' added to the 'docker' group.${NC}"
        echo -e "${YELLOW}  NOTE: For this change to take effect, you must log out and log back in, or run 'newgrp docker' in a new shell.${NC}"
    else
        echo -e "${RED}  Error adding user '$TARGET_USER' to the 'docker' group.${NC}"
        FAILED_STEPS+=("Docker Group Add")
    fi
    echo "---------------------------------------------------"
}

# --- Home-specific configurations (no commands currently) ---
_manage_home_services() {
    echo -e "${BLUE}Managing home-specific services...${NC}"
    echo -e "${YELLOW}  No home-specific services to manage.${NC}"
    echo "---------------------------------------------------"
}

# --- User-level configurations common to all setups (requires sudo -u $TARGET_USER) ---
_manage_user_tools() {
    echo -e "${BLUE}Configuring common user-level tools...${NC}"

    # Enable and start hyprsunset.service for the user
    echo -e "${YELLOW}  Enabling and starting hyprsunset.service for user '$TARGET_USER'...${NC}"
    if sudo -u "$TARGET_USER" systemctl --user enable --now hyprsunset.service; then
        echo -e "${GREEN}  hyprsunset.service enabled and started.${NC}"
    else
        echo -e "${RED}  Error enabling/starting hyprsunset.service.${NC}"
        FAILED_STEPS+=("Hyprsunset Service")
    fi

    # Add Flathub remote for Flatpak
    echo -e "${YELLOW}  Adding Flathub remote for Flatpak...${NC}"
    if sudo -u "$TARGET_USER" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
        echo -e "${GREEN}  Flathub remote added successfully.${NC}"
    else
        echo -e "${RED}  Error adding Flathub remote.${NC}"
        FAILED_STEPS+=("Flatpak Remote")
    fi

    # Install nvm using curl and bash, running as the user
    echo -e "${YELLOW}  Installing nvm for user '$TARGET_USER'...${NC}"
    if sudo -u "$TARGET_USER" bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"; then
        echo -e "${GREEN}  nvm installation script executed successfully.${NC}"
        echo -e "${YELLOW}  NOTE: For nvm to be available, please open a new shell or source your shell configuration file (e.g., 'source ~/.zshrc').${NC}"
    else
        echo -e "${RED}  Error running nvm installation script.${NC}"
        FAILED_STEPS+=("nvm Installation")
    fi
    echo "---------------------------------------------------"
}

# --- Main Execution Flow ---
_manage_common_services
_manage_user_tools

case "$SETUP_TYPE" in
    "home")
        _manage_home_services
        ;;
    "work")
        _manage_work_services
        ;;
    "all")
        _manage_home_services
        _manage_work_services
        ;;
    *)
        echo -e "${RED}  Error: Invalid or missing setup type. Running common services only.${NC}"
        ;;
esac

# Summary of failed steps
echo -e "\n${GREEN}--- Post-Setup Summary ---${NC}"
if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    echo -e "${GREEN}All post-setup steps completed successfully!${NC}"
else
    echo -e "${RED}The following steps failed:${NC}"
    for failed_step in "${FAILED_STEPS[@]}"; do
        echo -e "${RED}- $failed_step${NC}"
    done
    echo -e "${RED}Please review the output above for details.${NC}"
    exit 1 # Exit with a non-zero status if any step failed
fi

echo -e "${GREEN}Script finished.${NC}"
exit 0
