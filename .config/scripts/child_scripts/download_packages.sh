#!/bin/bash

# This script handles the installation of essential system packages and AUR packages.
# It first sets up 'yay' (an AUR helper) if not already present,
# then proceeds to install packages defined in arrays, checking if they exist first.
#
# IMPORTANT:
# - This script includes 'sudo' prefixes for commands requiring elevated privileges
#   (e.g., pacman, yay installation). When run by your master 'run_all_scripts.sh'
#   script (without sudo), each 'sudo' command will prompt for a password if needed.

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
    "zsh"
    "ufw"
    "github-cli"
    "wl-clipboard"
)

# AUR packages (install with yay)
declare -a YAY_PACKAGES=(
    "google-chrome"
    "visual-studio-code-bin" # VS Code from AUR
)

# Function to check if a package is installed
is_package_installed() {
    pacman -Q "$1" &> /dev/null
}

# Install Pacman packages
echo "Installing official Arch Linux packages (via pacman):"
for package in "${PACMAN_PACKAGES[@]}"; do
    if ! is_package_installed "$package"; then
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
        if ! is_package_installed "$package"; then
            echo "  - Installing $package (AUR)..."
            # yay drops privileges for building, but needs sudo for pacman part
            yay -S "$package" --noconfirm
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

# --- Installation Summary ---
echo -e "\n--- Package Installation Summary ---"
if [ ${#FAILED_PACKAGES[@]} -eq 0 ]; then
    echo "All specified packages were installed successfully!"
else
    echo "The following packages failed to install:"
    for failed_package in "${FAILED_PACKAGES[@]}"; do
        echo "  - $failed_package"
    done
    echo "Please review the output above for specific errors during installation."
fi

echo "---------------------------------------------------"
echo "Package installation setup complete!"
echo "You may need to reboot or log out/in for some changes (like shell defaults) to take full effect."
