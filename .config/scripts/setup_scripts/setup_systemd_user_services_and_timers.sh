#!/bin/bash

# This script is responsible for managing user-level systemd services and timers.
# It is designed to be called by a master script (run_setup_scripts.sh)
# and performs the following actions:
# - Performs a systemctl --user daemon-reload.
# - Enables and starts a list of specified systemd timers.
# - Starts a list of specified systemd services.
#
# The script is idempotent and can be re-run safely.

# --- Color Definitions for better readability ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting script to manage Systemd user services...${NC}"

# --- Sudo Elevation Check ---
# Check if the script is running with root privileges (EUID 0).
# If not, re-execute itself with sudo.
if [[ "$EUID" -ne 0 ]]; then
  echo "This script requires elevated privileges. Attempting to re-run with sudo..."
  # Preserve arguments when re-running with sudo
  exec sudo bash "$0" "$@"
  # The 'exec' command replaces the current shell process with the new one.
  # If sudo fails (e.g., user cancels password prompt), this script will exit.
fi

# Determine the target user and their home directory.
# SUDO_USER is set by 'sudo' to the original user who invoked sudo.
# If not running via sudo, it defaults to the current user.
TARGET_USER="${SUDO_USER:-$(whoami)}"
TARGET_HOME="/home/$TARGET_USER" # Assuming /home/user for non-root user

echo "Target user for operations: $TARGET_USER"
echo "Target home directory: $TARGET_HOME"
echo "---------------------------------------------------"

# Array to store failed steps
declare -a FAILED_STEPS=()

# 4. Commands for your symlinks (systemd --user services)
_manage_systemd_user_services() {
  echo -e "${BLUE}Managing Systemd User Services...${NC}"

  echo -e "${YELLOW}  Running systemctl --user daemon-reload...${NC}"
  if sudo -u "$TARGET_USER" systemctl --user daemon-reload; then
    echo -e "${GREEN}  daemon-reload successful.${NC}"
  else
    echo -e "${RED}  Error: systemctl --user daemon-reload failed.${NC}"
    FAILED_STEPS+=("Systemd Daemon Reload")
  fi

  local -a timers_to_enable_start=(
    "hyprsunset-night.timer"
    "hyprsunset-day.timer"
  )
  for timer in "${timers_to_enable_start[@]}"; do
    echo -e "${YELLOW}  Enabling and starting $timer...${NC}"
    if sudo -u "$TARGET_USER" systemctl --user enable "$timer"; then
      echo -e "${GREEN}  Enabled $timer.${NC}"
      if sudo -u "$TARGET_USER" systemctl --user start "$timer"; then
        echo -e "${GREEN}  Started $timer.${NC}"
      else
        echo -e "${RED}  Error starting $timer.${NC}"
        FAILED_STEPS+=("Systemd Start Error ($timer)")
      fi
    else
      echo -e "${RED}  Error enabling $timer.${NC}"
      FAILED_STEPS+=("Systemd Enable Error ($timer)")
    fi
  done

  local -a services_to_start=(
    "hyprsunset.service"
  )
  for service in "${services_to_start[@]}"; do
    echo -e "${YELLOW}  Starting $service...${NC}"
    if sudo -u "$TARGET_USER" systemctl --user start "$service"; then
      echo -e "${GREEN}  Started $service.${NC}"
    else
      echo -e "${RED}  Error starting $service.${NC}"
      FAILED_STEPS+=("Systemd Start Error ($service)")
    fi
  done
  echo "---------------------------------------------------"
}

# --- Main Execution Flow ---
_manage_systemd_user_services

# Summary of failed steps
echo -e "\n${GREEN}--- Systemd User Service Setup Summary ---${NC}"
if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    echo -e "${GREEN}All Systemd setup steps completed successfully!${NC}"
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
