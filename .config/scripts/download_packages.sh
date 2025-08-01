#!/bin/bash

# This script handles the installation of essential system packages, AUR packages,
# and Flatpak applications based on a specified setup type (home, work, or all).
# It first sets up 'yay' (an AUR helper) if not already present,
# then proceeds to install packages defined in arrays, checking if they exist first.
# It also sets up Flatpak and installs Flatpak applications.
#
# Usage: ~/.config/scripts/download_packages.sh [home|work|all]
#   If no argument is provided, or an invalid argument is provided,
#   the script will prompt the user to choose.
#   If this script is not executable, make it so with:
#   chmod +x ~/.config/scripts/download_packages.sh
#
# IMPORTANT:
# - This script includes 'sudo' prefixes for commands requiring elevated privileges
#   (e.g., pacman, yay installation, flatpak remote add). This script is designed
#   to handle its own sudo elevation, prompting for a password once at the start
#   if necessary.

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

echo "Starting package installation setup..."
echo "---------------------------------------------------"

# Determine the target user and their home directory.
# SUDO_USER is set by 'sudo' to the original user who invoked sudo.
# If not running via sudo, it defaults to the current user.
TARGET_USER="${SUDO_USER:-$(whoami)}"
TARGET_HOME="/home/$TARGET_USER" # Assuming /home/user for non-root user

echo "Target user for package installation: $TARGET_USER (Home: $TARGET_HOME)"

# --- Validate input argument or prompt user ---
SETUP_TYPE="$1"

# Function to prompt user for setup type
prompt_for_setup_type() {
  local choice=""
  while true; do
    echo "Please choose an option for package installation:"
    echo "  1) Home"
    echo "  2) Work"
    echo "  3) All (Home + Work)"
    echo "  4) EXIT (Do not install packages)"
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

echo "Selected setup type: $(echo "$SETUP_TYPE" | tr '[:lower:]' '[:upper:]')"
echo "---------------------------------------------------"

# Array to store failed packages
declare -a FAILED_PACKAGES=()

# --- Part 1: Setup Yay (AUR Helper) ---
# Ensure git and base-devel are installed before attempting to setup yay.
# These are included in COMMON_PACMAN_PACKAGES now.

# Check if yay is installed
if ! command -v yay &> /dev/null; then
  echo "yay (AUR helper) not found. Attempting to set up yay..."
  echo "  - First, ensuring 'git' and 'base-devel' are installed for building yay..."
  # Install dependencies needed for yay
  pacman -S git base-devel --noconfirm
  if [ $? -ne 0 ]; then
    echo "    Error: Failed to install yay dependencies (git, base-devel). Aborting yay setup."
    FAILED_PACKAGES+=("yay (Dependencies)")
  else
    echo "    Dependencies installed successfully."

    # Clone yay repository and build/install it
    # Use a temporary directory to avoid cluttering home
    TEMP_DIR=$(mktemp -d)
    echo "  - Cloning yay into $TEMP_DIR..."
    # When running with sudo elevation for the whole script, we still need
    # to drop privileges for git clone and makepkg, as they should be run
    # as the TARGET_USER.
    sudo -u "$TARGET_USER" git clone https://aur.archlinux.org/yay.git "$TEMP_DIR/yay"
    if [ $? -ne 0 ]; then
      echo "    Error: Failed to clone yay repository."
      FAILED_PACKAGES+=("yay (Clone)")
      rm -rf "$TEMP_DIR"
    else
      echo "  - Building and installing yay..."
      # Change ownership of the temp directory to the target user for makepkg
      # This chown can now run without sudo prefix, as the script itself is elevated
      chown -R "$TARGET_USER":"$TARGET_USER" "$TEMP_DIR"
      sudo -u "$TARGET_USER" sh -c "cd '$TEMP_DIR/yay' && makepkg -si --noconfirm"
      if [ $? -ne 0 ]; then
          echo "    Error: Failed to build and install yay."
          FAILED_PACKAGES+=("yay (Build/Install)")
      else
          echo "    yay installed successfully."
      fi
      rm -rf "$TEMP_DIR"
    fi
  fi
else
  echo "yay (AUR helper) is already installed."
fi

echo "---------------------------------------------------"

# --- Part 2: Package Definitions ---

# Official Arch Linux packages (install with pacman)
declare -a COMMON_PACMAN_PACKAGES=(
  "base-devel" # Essential for building AUR/YAY packages
  "bc"
  "curl" # Needed by ZSH
  "egl-wayland" # For graphics rendering
  "ffmpeg" # For screen recording (video encoding)
  "flatpak"
  "gimp"
  "git"
  "github-cli"
  "gnome-calculator"
  "gnome-text-editor"
  "grim" # For screen shots
  "hypridle"
  "hyprlock"
  "hyprsunset"
  "hyprpaper"
  "hyprpolkitagent"
  "lib32-mesa" # For graphics rendering
  "lib32-nvidia-utils" # Also setup in setup script - Steam Setup
  "lib32-vulkan-icd-loader" # Also setup in setup script - Steam Setup
  "lib32-vulkan-mesa-layers" # Also setup in setup script - Steam Setup
  "libnotify" # For desktop notifications
  "libva-nvidia-driver"
  "mesa" # For graphics rendering
  "mpv" # For vieweing mp4 files (For screen recordings)
  # "nautilus" # Setup in a setup script - Replace File Manager
  "networkmanager"
  "nvidia-dkms"
  "nvidia-settings"
  "nvidia-utils"
  "nodejs"
  "noto-fonts"
  "noto-fonts-cjk"
  "noto-fonts-emoji"
  "npm"
  # "nvidia-utils" # Setup in a setup script - Steam Setup
  # "nvm" # Downloaded via a bash command, to it works with the terminal
  "papirus-icon-theme"
  "pipewire" # For screen sharing
  "pipewire-pulse"
  "qt5-wayland"
  "qt6-wayland"
  "sass" # For AGS Widgets
  "slurp" # For screen shots
  "ttf-fira-code-nerd"
  "ttf-liberation"
  "ttf-nerd-fonts-symbols"
  "ttf-nerd-fonts-symbols-mono"
  # "ufw" # Setup in a setup script - UFW Setup
  "unzip"
  "vulkan-headers"
  "vulkan-icd-loader" # Setup in setup script - Steam Setup
  # "vulkan-mesa-layers" # Setup in setup script - Steam Setup
  "vulkan-tools"
  "waybar"
  "webkit2gtk-4.1" # For VPN Usage
  "wev" # Keyboard Troubleshooter
  "wf-recorder" # For screen recording
  # "wine-staging" # Setup in setup script - Steam Setup
  # "winetricks" # Setup in setup script - Steam Setup
  "wireplumber" # For screen sharing
  "wl-clipboard" # For screen shots
  "wtype" # For keyboard input simulation/debugging
  "xdg-desktop-portal" # For screen sharing
  "xdg-desktop-portal-hyprland" # For screen sharing
  # "xdg-utils" # Setup in a setup script - Replace File Manager
  "xorg-xeyes" # XWayland Tester/Debugger
  "ydotool" # Input Creation Tool
  # "zsh" # Setup in a setup script - ZSH Setup
)
declare -a HOME_PACMAN_PACKAGES=(
  "gamescope"
  "jdk8-openjdk" # Minecraft 1.12.x - 1.16.5
  "jdk17-openjdk" # Minecraft 1.17.x - 1.20.5
  "jdk21-openjdk" # Minecraft 1.20.6 - 1.21.x
  # "steam" # Setup in a setup script - Steam Setup
)
declare -a WORK_PACMAN_PACKAGES=(
  "docker"
  "docker-compose"
  "networkmanager-openconnect"
  "openconnect"
)

# AUR packages (install with yay)
declare -a COMMON_YAY_PACKAGES=(
  "aylurs-gtk-shell-git" # AGS Widgets
  "google-chrome"
  "grimblast-git" # For screen shots
  "ttf-ms-fonts"
  "visual-studio-code-bin"
  "xdg-desktop-portal-hyprland-git" # For screen sharing
)
declare -a HOME_YAY_PACKAGES=(
  "discord"
  "minecraft-launcher"
  "prismlauncher"
  # "proton-ge-custom" # Setup in a setup script - Steam Setup
)
declare -a WORK_YAY_PACKAGES=(
  "cisco-secure-client"
  "slack-desktop"
  "zoom"
)

# Flatpak applications
declare -a COMMON_FLATPAK_PACKAGES=()
declare -a HOME_FLATPAK_PACKAGES=(
  "org.vinegarhq.Sober" # Roblox Player
)
declare -a WORK_FLATPAK_PACKAGES=()

# --- Part 3: Installation Functions ---

# Function to check if a pacman package is installed
is_pacman_package_installed() {
  pacman -Q "$1" &> /dev/null
}

# Function to check if a Flatpak application is installed
is_flatpak_app_installed() {
  # Use sudo -u "$TARGET_USER" to run flatpak list as the target user
  # No "sudo" prefix needed for flatpak command itself as script is already elevated.
  # Still need sudo -u to specify running as TARGET_USER.
  sudo -u "$TARGET_USER" flatpak list --app | grep -q "^$1/"
}

# Function to install Pacman packages from an array
install_pacman_packages() {
  local -n packages_array=$1 # Use nameref for array
  local type_label=$2

  if [ ${#packages_array[@]} -eq 0 ]; then
    echo "  No $type_label Pacman packages to install."
    return
  fi

  echo "Installing $type_label Arch Linux packages (via pacman):"
  for package in "${packages_array[@]}"; do
    if ! is_pacman_package_installed "$package"; then
      echo "  - Installing $package..."
      # No "sudo" prefix needed here, as the script is already running as root.
      pacman -S "$package" --noconfirm
      if [ $? -ne 0 ]; then
        echo "    Error: Failed to install $package."
        FAILED_PACKAGES+=("$package (pacman-$type_label)")
      else
        echo "    $package installed successfully."
      fi
    else
      echo "  - $package is already installed."
    fi
  done
}

# Function to install AUR packages from an array
install_yay_packages() {
  local -n packages_array=$1 # Use nameref for array
  local type_label=$2

  if [ ${#packages_array[@]} -eq 0 ]; then
      echo "  No $type_label AUR packages to install."
      return
  fi

  echo "Installing $type_label AUR packages (via yay):"
  # Check if yay command is available before attempting AUR installs
  if command -v yay &> /dev/null; then
    for package in "${packages_array[@]}"; do
      if ! is_pacman_package_installed "$package"; # yay packages also show up in pacman -Q
      then
        echo "  - Installing $package (AUR)..."
        # yay drops privileges for building, but needs sudo for pacman part.
        # Since the script is already running as root, we *still* need to
        # use 'sudo -u "$TARGET_USER"' to ensure yay builds as the normal user.
        sudo -u "$TARGET_USER" yay -S "$package" --noconfirm
        if [ $? -ne 0 ]; then
          echo "    Error: Failed to install $package (AUR)."
          FAILED_PACKAGES+=("$package (yay-$type_label)")
        else
          echo "    $package installed successfully."
        fi
      else
        echo "  - $package (AUR) is already installed."
      fi
    done
  else
    echo "  yay is not installed. Skipping AUR package installation for $type_label."
  fi
}

# Function to install Flatpak applications from an array
install_flatpak_apps() {
  local -n apps_array=$1 # Use nameref for array
  local type_label=$2

  if [ ${#apps_array[@]} -eq 0 ]; then
    echo "  No $type_label Flatpak apps to install."
    return
  fi

  echo "Installing $type_label Flatpak applications:"
  # Check if flatpak is installed from pacman
  if ! command -v flatpak &> /dev/null; then
    echo "Error: Flatpak is not installed. Cannot proceed with Flatpak app installation for $type_label."
    FAILED_PACKAGES+=("Flatpak (core utility not found for $type_label)")
    return
  fi

  # Add Flathub remote if not already added
  echo "  - Adding Flathub remote if not already present..."
  # Use sudo -u "$TARGET_USER" for user-specific flatpak commands.
  # The script is elevated, so `flatpak` itself doesn't need `sudo`.
  # But `remote-add --user` needs to be run *as the user*.
  if ! sudo -u "$TARGET_USER" flatpak remotes --user | grep -q "flathub"; then
    sudo -u "$TARGET_USER" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    if [ $? -ne 0 ]; then
      echo "    Error: Failed to add Flathub remote."
      FAILED_PACKAGES+=("Flathub Remote")
    else
      echo "    Flathub remote added successfully."
    fi
  else
    echo "    Flathub remote is already added."
  fi

  for app_id in "${apps_array[@]}"; do
    if ! is_flatpak_app_installed "$app_id"; then
      echo "  - Installing Flatpak app: $app_id..."
      # Use sudo -u "$TARGET_USER" to install flatpak apps for the user
      sudo -u "$TARGET_USER" flatpak install flathub "$app_id" --or-update --noninteractive
      if [ $? -ne 0 ]; then
        echo "    Error: Failed to install Flatpak app: $app_id."
        FAILED_PACKAGES+=("$app_id (Flatpak-$type_label)")
      else
        echo "    Flatpak app $app_id installed successfully."
      fi
    else
      echo "  - Flatpak app $app_id is already installed."
    fi
  done
}

# --- Part 4: Execute Installation Based on Setup Type ---

echo "---------------------------------------------------"
echo "Starting COMMON package installations..."
install_pacman_packages COMMON_PACMAN_PACKAGES "COMMON"
install_yay_packages COMMON_YAY_PACKAGES "COMMON"
install_flatpak_apps COMMON_FLATPAK_PACKAGES "COMMON"
echo "COMMON package installations complete."

echo "---------------------------------------------------"

if [[ "$SETUP_TYPE" == "home" || "$SETUP_TYPE" == "all" ]]; then
  echo "Starting HOME specific package installations..."
  install_pacman_packages HOME_PACMAN_PACKAGES "HOME"
  install_yay_packages HOME_YAY_PACKAGES "HOME"
  install_flatpak_apps HOME_FLATPAK_PACKAGES "HOME"
  echo "HOME specific package installations complete."
fi

echo "---------------------------------------------------"

if [[ "$SETUP_TYPE" == "work" || "$SETUP_TYPE" == "all" ]]; then
  echo "Starting WORK specific package installations..."
  install_pacman_packages WORK_PACMAN_PACKAGES "WORK"
  install_yay_packages WORK_YAY_PACKAGES "WORK"
  install_flatpak_apps WORK_FLATPAK_PACKAGES "WORK"
  echo "WORK specific package installations complete."
fi

echo "---------------------------------------------------"

# --- Installation Summary ---
echo -e "\n--- Package Installation Summary ---"
if [ ${#FAILED_PACKAGES[@]} -eq 0 ]; then
  echo "All specified packages and applications were installed successfully!"
else
  echo "The following packages/applications failed to install:"
  for failed_item in "${FAILED_PACKAGES[@]}"; do
    echo "  - $failed_item"
  done
  echo "Please review the output above for specific errors during installation."
fi

echo "---------------------------------------------------"
echo "Package installation setup complete!"
echo "You may need to reboot or log out/in for some changes (like shell defaults) to take full effect."