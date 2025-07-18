#!/bin/bash

# This script handles the installation of essential system packages, AUR packages,
# and Flatpak applications.
# It first sets up 'yay' (an AUR helper) if not already present,
# then proceeds to install packages defined in arrays, checking if they exist first.
# It also sets up Flatpak and installs Flatpak applications.
#
# IMPORTANT:
# - This script includes 'sudo' prefixes for commands requiring elevated privileges
#   (e.g., pacman, yay installation, flatpak remote add). When run by your master
#   'run_all_scripts.sh' script (without sudo), each 'sudo' command will prompt
#   for a password if needed.

echo "Starting package installation setup..."
echo "---------------------------------------------------"

# Determine the target user and their home directory.
# SUDO_USER is set by 'sudo' to the original user who invoked sudo.
# If not running via sudo, it defaults to the current user.
TARGET_USER="${SUDO_USER:-$(whoami)}"
TARGET_HOME="/home/$TARGET_USER" # Assuming /home/user for non-root user

echo "Target user for package installation: $TARGET_USER (Home: $TARGET_HOME)"

# Array to store failed packages
declare -a FAILED_PACKAGES=()

# --- Pre-requisites for Yay and AUR packages ---
# Ensure git and base-devel are installed before attempting to setup yay or other AUR packages.
declare -a PREREQ_PACKAGES=(
    "git"        # Essential for cloning yay and other repositories
    "base-devel" # Essential for building AUR packages (includes make, gcc, etc.)
    "curl"       # Needed by Oh My Zsh installer (good to have early)
)

echo "Installing pre-requisite packages (git, base-devel, curl)..."
for package in "${PREREQ_PACKAGES[@]}"; do
    if ! pacman -Q "$package" &> /dev/null; then
        echo "  - Installing $package..."
        sudo pacman -S "$package" --noconfirm
        if [ $? -ne 0 ]; then
            echo "    Error: Failed to install pre-requisite package: $package."
            FAILED_PACKAGES+=("$package (Prerequisite)")
            # Do not exit here, try to continue with other prereqs, but yay setup might fail
        else
            echo "    $package installed successfully."
        fi
    else
        echo "  - $package is already installed."
    fi
done

echo "---------------------------------------------------"

# --- Part 1: Setup Yay (AUR Helper) ---
# Check if yay is installed
if ! command -v yay &> /dev/null; then
    echo "yay (AUR helper) not found. Attempting to set up yay..."

    # Clone yay repository and build/install it
    # Use a temporary directory to avoid cluttering home
    TEMP_DIR=$(mktemp -d)
    echo "Cloning yay into $TEMP_DIR..."
    sudo -u "$TARGET_USER" git clone https://aur.archlinux.org/yay.git "$TEMP_DIR/yay"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone yay repository."
        FAILED_PACKAGES+=("yay (Clone)")
        rm -rf "$TEMP_DIR"
    else
        echo "Building and installing yay..."
        # Change ownership of the temp directory to the target user for makepkg
        sudo chown -R "$TARGET_USER":"$TARGET_USER" "$TEMP_DIR"
        sudo -u "$TARGET_USER" sh -c "cd '$TEMP_DIR/yay' && makepkg -si --noconfirm"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to build and install yay. Please ensure all 'base-devel' components are functional."
            FAILED_PACKAGES+=("yay (Build/Install)")
        else
            echo "yay installed successfully."
        fi
        rm -rf "$TEMP_DIR"
    fi
else
    echo "yay (AUR helper) is already installed."
fi

echo "---------------------------------------------------"

# --- Part 2: Package Installation ---

# Define arrays for packages
# Official Arch Linux packages (install with pacman)
declare -a PACMAN_PACKAGES=(
    "docker"
    "docker-compose"
    "ffmpeg" # For screen recording (video encoding)
    "flatpak"
    "gimp"
    "github-cli"
    "gnome-calculator"
    "gnome-text-editor"
    "grim" # For screen shots
    "hypridle"
    "hyprlock"
    "hyprsunset"
    "hyprpaper"
    "hyprpolkitagent"
    "jre-openjdk-headless"
    "jre17-openjdk-headless"
    # "lib32-nvidia-utils" # Setup in child script - Steam Setup
    # "lib32-vulkan-icd-loader" # Setup in child script - Steam Setup
    # "lib32-vulkan-mesa-layers" # Setup in child script - Steam Setup
    "libnotify"
    "libva-nvidia-driver"
    "lxappearance"
    "mpv" # For vieweing mp4 files (For screen recordings)
    # "nautilus" # Setup in a child script - Replace File Manager
    "networkmanager"
    "networkmanager-openconnect"
    "nodejs"
    "npm"
    # "nvidia-utils" # Setup in a child script - Steam Setup
    "nvm"
    "openconnect"
    "papirus-icon-theme"
    "pipewire" # For screen sharing
    "pipewire-pulse"
    "qt5-wayland"
    "qt6-wayland"
    "slurp" # For screen shots
    # "steam" # Setup in child script - Steam Setup
    "ttf-fira-code-nerd"
    # "ufw" # Setup in a child script - UFW Setup
    "unzip"
    # "vulkan-icd-loader" # Setup in child script - Steam Setup
    # "vulkan-mesa-layers" # Setup in child script - Steam Setup
    "waybar"
    "webkit2gtk-4.1" # For VPN Usage
    "wf-recorder" # For screen recording
    # "wine-staging" # Setup in child script - Steam Setup
    # "winetricks" # Setup in child script - Steam Setup
    "wireplumber" # For screen sharing
    "wl-clipboard" # For screen shots
    "xdg-desktop-portal" # For screen sharing
    "xdg-desktop-portal-hyprland" # For screen sharing
    # "xdg-utils" # Setup in a child script - Replace File Manager
    # "zsh" # Setup in a child script - ZSH Setup
)

# AUR packages (install with yay)
declare -a YAY_PACKAGES=(
    "cisco-secure-client"
    "discord"
    "google-chrome"
    "grimblast-git" # For screen shots
    # "proton-ge-custom" # Setup in child script - Steam Setup
    "slack-desktop"
    "visual-studio-code-bin"
    "xdg-desktop-portal-hyprland-git" # For screen sharing
    "zoom"
)

# Flatpak applications
declare -a FLATPAK_PACKAGES=(
    "org.vinegarhq.Sober" # Roblox Player
)

# Function to check if a pacman package is installed
is_pacman_package_installed() {
    pacman -Q "$1" &> /dev/null
}

# Function to check if a Flatpak application is installed
is_flatpak_app_installed() {
    # Use sudo -u "$TARGET_USER" to run flatpak list as the target user
    sudo -u "$TARGET_USER" flatpak list --app | grep -q "^$1/"
}


# Install Pacman packages
echo "Installing official Arch Linux packages (via pacman):"
for package in "${PACMAN_PACKAGES[@]}"; do
    if ! is_pacman_package_installed "$package"; then
        echo "  - Installing $package..."
        sudo pacman -S "$package" --noconfirm
        if [ $? -ne 0 ]; then
            echo "    Error: Failed to install $package."
            FAILED_PACKAGES+=("$package (pacman)")
        else
            echo "    $package installed successfully."
        fi
    else
        echo "  - $package is already installed."
    fi
done

echo "---------------------------------------------------"

# Install AUR packages
echo "Installing AUR packages (via yay):"
# Check if yay command is available before attempting AUR installs
if command -v yay &> /dev/null; then
    for package in "${YAY_PACKAGES[@]}"; do
        if ! is_pacman_package_installed "$package"; then # yay packages also show up in pacman -Q
            echo "  - Installing $package (AUR)..."
            # yay drops privileges for building, but needs sudo for pacman part
            sudo -u "$TARGET_USER" yay -S "$package" --noconfirm
            if [ $? -ne 0 ]; then
                echo "    Error: Failed to install $package (AUR)."
                FAILED_PACKAGES+=("$package (yay)")
            else
                echo "    $package installed successfully."
            fi
        else
            echo "  - $package (AUR) is already installed."
        fi
    done
else
    echo "  yay is not installed. Skipping AUR package installation."
fi

echo "---------------------------------------------------"

# --- Part 3: Flatpak Setup and Installation ---
echo "Setting up Flatpak and installing Flatpak applications:"

# Check if flatpak is installed from pacman
if ! command -v flatpak &> /dev/null; then
    echo "Error: Flatpak is not installed. Cannot proceed with Flatpak app installation."
    FAILED_PACKAGES+=("Flatpak (core utility not found)")
else
    # Add Flathub remote if not already added
    echo "  - Adding Flathub remote if not already present..."
    # Use sudo -u "$TARGET_USER" for user-specific flatpak commands
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

    # Install Flatpak applications
    for app_id in "${FLATPAK_PACKAGES[@]}"; do
        if ! is_flatpak_app_installed "$app_id"; then
            echo "  - Installing Flatpak app: $app_id..."
            # Use sudo -u "$TARGET_USER" to install flatpak apps for the user
            sudo -u "$TARGET_USER" flatpak install flathub "$app_id" --or-update --noninteractive
            if [ $? -ne 0 ]; then
                echo "    Error: Failed to install Flatpak app: $app_id."
                FAILED_PACKAGES+=("$app_id (Flatpak)")
            else
                echo "    Flatpak app $app_id installed successfully."
            fi
        else
            echo "  - Flatpak app $app_id is already installed."
        fi
    done
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