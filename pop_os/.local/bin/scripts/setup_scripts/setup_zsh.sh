#!/bin/bash

# This script sets up Zsh, Oh My Zsh, and the zsh-autosuggestions plugin,
# and symlinks the .zshrc from the user's dotfiles repository.
#
# IMPORTANT:
# - This script expects to be run with sufficient permissions for package
#   installation and shell modification (e.g., using `sudo`).
# - This script assumes the user's dotfiles repository is located at
#   '~/Development/repos/dotfiles'. Please update the DOTFILES_SOURCE
#   variable if this path is incorrect.

echo "Starting Zsh setup..."
echo "---------------------------------------------------"

# Determine the target user and their home directory.
# This makes the script compatible with being run via `sudo`.
TARGET_USER="${SUDO_USER:-$(whoami)}"
TARGET_HOME="/home/$TARGET_USER"

echo "Target user for Zsh setup: $TARGET_USER (Home: $TARGET_HOME)"

# 1. Install Zsh
if ! command -v zsh &> /dev/null; then
    echo "Zsh not found. Installing zsh using apt..."
    sudo apt-get update
    sudo apt-get install -y zsh
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install zsh. Please check your internet connection or package manager. Exiting."
        exit 1
    fi
else
    echo "Zsh is already installed."
fi

# 2. Install Oh My Zsh
if [ ! -d "$TARGET_HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh not found. Installing Oh My Zsh for user '$TARGET_USER'..."
    # The --unattended flag avoids interactive prompts. We use 'sudo -u "$TARGET_USER"'
    # to ensure Oh My Zsh is installed and owned by the regular user.
    sudo -u "$TARGET_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Oh My Zsh. Exiting."
        exit 1
    fi
else
    echo "Oh My Zsh is already installed."
fi

# 3. Configure .zshrc from dotfiles
# This step deletes the default .zshrc created by Oh My Zsh and
# symlinks the user's dotfile into place.
DOTFILES_SOURCE="$TARGET_HOME/Development/repos/dotfiles/pop_os/.zshrc"
ZSHRC_DESTINATION="$TARGET_HOME/.zshrc"

echo "Configuring .zshrc from dotfiles..."

# Check if the dotfile source exists
if [ ! -f "$DOTFILES_SOURCE" ]; then
    echo "  - Warning: Dotfile not found at '$DOTFILES_SOURCE'. Skipping .zshrc setup."
    echo "    Please ensure your dotfiles repository is cloned and contains the .zshrc file."
else
    # Delete the existing ~/.zshrc (e.g., the one created by Oh My Zsh)
    if [ -f "$ZSHRC_DESTINATION" ]; then
        echo "  - Deleting existing ~/.zshrc file..."
        sudo -u "$TARGET_USER" rm "$ZSHRC_DESTINATION"
    fi

    # Create the symbolic link
    echo "  - Creating symlink from '$DOTFILES_SOURCE' to '$ZSHRC_DESTINATION'..."
    sudo -u "$TARGET_USER" ln -sf "$DOTFILES_SOURCE" "$ZSHRC_DESTINATION"
    if [ $? -ne 0 ]; then
        echo "    Error: Failed to create symlink. Exiting."
        exit 1
    fi
    echo "    Symlink created successfully."
fi

# 4. Install zsh-autosuggestions plugin
ZSH_CUSTOM_DIR="${TARGET_HOME}/.oh-my-zsh/custom"
ZSH_PLUGINS_DIR="${ZSH_CUSTOM_DIR}/plugins"
AUTOSUGGESTIONS_REPO="https://github.com/zsh-users/zsh-autosuggestions"
AUTOSUGGESTIONS_DIR="${ZSH_PLUGINS_DIR}/zsh-autosuggestions"

if [ ! -d "$AUTOSUGGESTIONS_DIR" ]; then
    echo "zsh-autosuggestions plugin not found. Cloning repository for user '$TARGET_USER'..."
    # Ensure plugins directory exists and is owned by the target user
    sudo -u "$TARGET_USER" mkdir -p "$ZSH_PLUGINS_DIR"
    sudo -u "$TARGET_USER" git clone "$AUTOSUGGESTIONS_REPO" "$AUTOSUGGESTIONS_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone zsh-autosuggestions. Exiting."
        exit 1
    fi
else
    echo "zsh-autosuggestions plugin is already installed."
fi
# NOTE: The script previously attempted to modify .zshrc to enable this plugin.
# With the new symlinking approach, you should manage plugins directly in your
# dotfile located at '$DOTFILES_SOURCE'.

# 5. Set default shell to Zsh for the target user
if [ "$(getent passwd "$TARGET_USER" | cut -d: -f7)" != "$(which zsh)" ]; then
    echo "Setting default shell for $TARGET_USER to Zsh..."
    sudo chsh -s "$(which zsh)" "$TARGET_USER"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to set default shell to zsh for $TARGET_USER. Exiting."
        exit 1
    fi
else
    echo "Default shell for $TARGET_USER is already Zsh."
fi

echo "---------------------------------------------------"
echo "Zsh setup complete!"
echo "If these changes weren't applied automatically,"
echo "you can manually run 'source $ZSHRC_DESTINATION' in your *current*"
echo "terminal to apply the .zshrc changes for this session."