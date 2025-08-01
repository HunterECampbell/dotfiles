#!/bin/bash

# This script sets up Zsh, Oh My Zsh, and the zsh-autosuggestions plugin.
# It is designed to be run as a child script by a master script.
#
# IMPORTANT:
# - This script expects to be run with sufficient permissions for package installation
#   and shell modification (e.g., via 'sudo' for pacman and chsh, or by a master
#   script that itself is run with sudo and doesn't drop privileges).
# - The current version of this script includes 'sudo' prefixes for commands
#   requiring elevated privileges, assuming it will be run by a normal user
#   or by a master script that doesn't pass root privileges directly.
#   Each 'sudo' command will prompt for a password if needed.

echo "Starting Zsh setup..."
echo "---------------------------------------------------"

# Determine the target user and their home directory.
# SUDO_USER is set by 'sudo' to the original user who invoked sudo.
# If not running via sudo, it defaults to the current user.
TARGET_USER="${SUDO_USER:-$(whoami)}"
TARGET_HOME="/home/$TARGET_USER" # Assuming /home/user for non-root user

echo "Target user for Zsh setup: $TARGET_USER (Home: $TARGET_HOME)"

# 1. Install Zsh
if ! command -v zsh &> /dev/null; then
    echo "Zsh not found. Installing zsh..."
    sudo pacman -S zsh --noconfirm # --noconfirm avoids manual 'y' prompt
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install zsh. Please check your internet connection or package manager. Exiting."
        exit 1
    fi
else
    echo "Zsh is already installed."
fi

# 2. Install Oh My Zsh
# Oh My Zsh installer typically creates a default .zshrc if one doesn't exist,
# or backs up an existing one to .zshrc.pre-oh-my-zsh.
# Your dotfiles process should then place your desired .zshrc at $TARGET_HOME/.zshrc.
# This script will then modify that .zshrc in a later step.
if [ ! -d "$TARGET_HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh not found. Installing Oh My Zsh for user '$TARGET_USER'..."
    # The --unattended flag avoids interactive prompts and attempts to set zsh as default shell (which we'll do explicitly later).
    # It will also backup an existing .zshrc if one exists.
    # We use 'sudo -u "$TARGET_USER"' to ensure Oh My Zsh is installed and owned by the regular user.
    sudo -u "$TARGET_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Oh My Zsh. Exiting."
        exit 1
    fi
else
    echo "Oh My Zsh is already installed."
fi

# 3. Install zsh-autosuggestions plugin
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

# 4. Update .zshrc to enable zsh-autosuggestions plugin
# This assumes your desired .zshrc (from your dotfiles) is already in place
# at $TARGET_HOME/.zshrc.
ZSHRC_PATH="$TARGET_HOME/.zshrc"
if [ -f "$ZSHRC_PATH" ]; then
    if ! sudo -u "$TARGET_USER" grep -q "zsh-autosuggestions" "$ZSHRC_PATH"; then
        echo "Adding zsh-autosuggestions to plugins in $ZSHRC_PATH..."
        # Use sed to add the plugin. Need to be careful with sudo and user permissions.
        # sed -i requires a backup file on macOS, so using a temp file for cross-platform compatibility.
        # We use 'sudo -u "$TARGET_USER"' to ensure the file is modified by the correct user.
        sudo -u "$TARGET_USER" sed -i.bak '/^plugins=(/ s/)$/ zsh-autosuggestions)/' "$ZSHRC_PATH"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to update .zshrc for zsh-autosuggestions."
            # Restore backup if sed failed, silently
            sudo -u "$TARGET_USER" mv "${ZSHRC_PATH}.bak" "$ZSHRC_PATH" 2>/dev/null || true
            exit 1
        else
            echo "Successfully added zsh-autosuggestions to plugins."
            # Remove backup file, silently
            sudo -u "$TARGET_USER" rm "${ZSHRC_PATH}.bak" 2>/dev/null || true
        fi
    else
        echo "zsh-autosuggestions already enabled in $ZSHRC_PATH."
    fi
else
    echo "Warning: .zshrc not found at $ZSHRC_PATH. Cannot configure plugins. Please ensure your .zshrc is in place."
fi

# 5. Set default shell to Zsh for the target user
# This command requires sudo as it modifies /etc/passwd.
# It's important to specify the TARGET_USER to ensure the shell is changed for the correct user.
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
echo "IMPORTANT: For these changes to take full effect, you MUST close your current"
echo "terminal window(s) and open a new one. This will load Zsh as your default shell"
echo "and apply the updated .zshrc configuration."
echo "Running 'source $TARGET_HOME/.zshrc' in your *current* Zsh session (if already Zsh)"
echo "will apply the .zshrc changes, but the default shell change requires a new login."
