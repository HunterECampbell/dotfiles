#!/bin/bash

# This script performs the initial setup for dotfile symlinks and permissions.
# It is designed to be called by a master script (run_setup_scripts.sh)
# and performs the following actions:
# - Creates necessary initial directories for dotfiles.
# - Creates symbolic links from a dotfiles repository to the user's home directory.
#
# The script is idempotent and can be re-run safely.

# --- Color Definitions for better readability ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting script to set up dotfile symlinks and permissions...${NC}"

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

# Define paths relative to TARGET_HOME
DOTFILES_REPO_DIR="$TARGET_HOME/Development/repos/dotfiles"

# Array to store failed steps
declare -a FAILED_STEPS=()

# 1. Directories to create before symlinking
_create_initial_dirs() {
  echo -e "${BLUE}Creating initial directories...${NC}"
  local -a dirs_to_create=(
    "$TARGET_HOME/.config/systemd"
    "$TARGET_HOME/Development"
    # Note: Other parent directories like ~/.config/hypr are created
    # by the parent script before this script runs.
  )

  for dir in "${dirs_to_create[@]}"; do
    if sudo -u "$TARGET_USER" mkdir -p "$dir"; then
      echo -e "${GREEN}  Created/Ensured directory: $dir${NC}"
    else
      echo -e "${RED}  Error creating directory: $dir${NC}"
      FAILED_STEPS+=("Directory Creation ($dir)")
    fi
  done
  echo "---------------------------------------------------"
}

# 2. Commands for symlinks
_create_dotfile_symlinks() {
  echo -e "${BLUE}Creating dotfile symlinks...${NC}"
  # Define symlinks in two separate, corresponding arrays to prevent parsing issues
  local -a src_paths=(
    "$DOTFILES_REPO_DIR/.config/hypr"
    "$DOTFILES_REPO_DIR/.config/mpv"
    "$DOTFILES_REPO_DIR/.config/scripts"
    "$DOTFILES_REPO_DIR/.config/systemd/user"
    "$DOTFILES_REPO_DIR/.config/waybar"
    "$DOTFILES_REPO_DIR/.config/widgets"
    "$DOTFILES_REPO_DIR/.config/wofi"
    "$DOTFILES_REPO_DIR/.config/zoomus.conf"
    "$DOTFILES_REPO_DIR/Development/Test Files"
    "$DOTFILES_REPO_DIR/Pictures/Wallpapers"
    "$DOTFILES_REPO_DIR/.zshrc"
  )

  local -a dest_paths=(
    "$TARGET_HOME/.config/hypr"
    "$TARGET_HOME/.config/mpv"
    "$TARGET_HOME/.config/scripts"
    "$TARGET_HOME/.config/systemd/user"
    "$TARGET_HOME/.config/waybar"
    "$TARGET_HOME/.config/widgets"
    "$TARGET_HOME/.config/wofi"
    "$TARGET_HOME/.config/zoomus.conf"
    "$TARGET_HOME/Development/Test Files"
    "$TARGET_HOME/Pictures/Wallpapers"
    "$TARGET_HOME/.zshrc"
  )

  # Loop through the arrays to create the symlinks
  for i in "${!src_paths[@]}"; do
    local source_path="${src_paths[$i]}"
    local target_path="${dest_paths[$i]}"

    # Check if target already exists and is a correct symlink
    if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
      echo -e "${GREEN}  Symlink already exists and is correct: $target_path -> $source_path${NC}"
    elif [[ -e "$target_path" ]]; then
      echo -e "${YELLOW}  Warning: Target '$target_path' already exists and is NOT a symlink to '$source_path'. Skipping.${NC}"
      echo -e "${YELLOW}  Please review manually. If you want to replace it, delete it first: rm -rf '$target_path'${NC}"
      FAILED_STEPS+=("Symlink Error (Exists: $target_path)")
    else
      echo -e "${YELLOW}  Creating symlink: $target_path -> $source_path${NC}"
      # Use `ln -sfn` to force overwrite existing files/symlinks
      if sudo -u "$TARGET_USER" ln -sfn "$source_path" "$target_path"; then
        echo -e "${GREEN}  Successfully created symlink: $target_path${NC}"
      else
        echo -e "${RED}  Error creating symlink: $target_path -> $source_path${NC}"
        FAILED_STEPS+=("Symlink Creation Error ($target_path)")
      fi
    fi
  done
  echo "---------------------------------------------------"
}

# --- Main Execution Flow ---
_create_initial_dirs
_create_dotfile_symlinks

# Summary of failed steps
echo -e "\n${GREEN}--- Dotfile Setup Summary ---${NC}"
if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    echo -e "${GREEN}All dotfile setup steps completed successfully!${NC}"
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
