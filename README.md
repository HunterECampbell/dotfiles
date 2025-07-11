# My Arch Linux Dotfiles

This repository contains my personal configuration files (dotfiles) and setup scripts for an Arch Linux environment, specifically tailored for Hyprland.

## Table of Contents

1. [Initial Arch Linux Installation](#1-initial-arch-linux-installation)
1. [Post-Installation Setup](#2-post-installation-setup)
    - [Cloning the Dotfiles Repository](#3-github-cli-setup)
    - [Symlinking Dotfiles](#4-important-notes)
    - [Running Setup Scripts](#running-setup-scripts)
1. [GitHub CLI Setup](#3-github-cli-setup)
1. [Important Notes](#4-important-notes)

## 1. Initial Arch Linux Installation

During the `archinstall` process, consider the following for a smooth setup with these dotfiles:

**User Account:** Create a non-root user (e.g., `hcnureth`). All dotfiles and scripts are designed to be managed by this user.

**File Management:** Select *ext4*

**Desktop Environment:** Select *Hyprland*

**Graphics Drivers:** Select *Nvidia (Proprietary)*

**Network Configuration:** Select *NetworkManager*

**Basic Utilities:** The `run_all_scripts.sh` script will download all necessary utilities

## 2. Post-Installation Setup

After a fresh Arch Linux installation and rebooting into your new system:

### Cloning the Dotfiles Repository

First, clone this repository to your home directory:

```
git clone https://github.com/HunterECampbell/dotfiles.git ~/dotfiles
```

### Symlinking Dotfiles

This repository uses symbolic links to manage dotfiles. This means the actual configuration files live in `~/dotfiles/`, and symlinks point from their traditional locations (e.g., `~/.zshrc`) to these files.

Example commands for symlinking (adjust paths and files as needed for your setup):

```
# Back up existing files if they exist (optional, but recommended)
[ -f ~/.zshrc ] && mv ~/.zshrc ~/.zshrc.bak
[ -d ~/.config/scripts ] && mv ~/.config/scripts ~/.config/scripts.bak
# ... (repeat for other configs like ~/.config/hypr, ~/.config/kitty, etc.)

# Create symlinks from your dotfiles repo to your home directory
ln -s ~/dotfiles/.zshrc ~/.zshrc
ln -s ~/dotfiles/.config/scripts ~/.config/scripts
ln -s ~/dotfiles/.config/hypr ~/.config/hypr
# ... (add more symlinks for other configs you've put in ~/dotfiles/.config/)
```

### Running Setup Scripts

Your setup scripts are located in `~/dotfiles/.config/scripts/child_scripts/`. The `run_all_scripts.sh` (found in `~/dotfiles/.config/scripts/`) master script will execute them.

**1. Make the master script executable (if not already):**

```
chmod +x ~/.config/scripts/run_all_scripts.sh
```

**2. Run the master script:**

This script will execute child scripts, which will handle package installations, Zsh setup, UFW configuration, etc. Child scripts that require elevated privileges will prompt you for your sudo password.

```
~/.config/scripts/run_all_scripts.sh
```


**Note:** Pay attention to the output. If any child script fails, the master script will report it at the end.

## 3. GitHub CLI Setup

For seamless interaction with GitHub from your terminal (e.g., `git push`, `git pull` without password prompts), it's highly recommended to set up `github-cli` (`gh`).

Refer to the dedicated guide: [github-cli-setup.md](./github-cli-setup.md)

## 4. Important Notes

- **Reboot/Relogin:** After running the setup scripts, it's often necessary to reboot your system or log out and log back in for all changes (especially shell changes and display manager configurations) to take full effect.

- **Customization:** These dotfiles reflect my personal preferences. Feel free to modify them to suit your needs!

- **Troubleshooting:** If you encounter issues, check the output of the `run_all_scripts.sh` script for error messages. Consult the Arch Wiki for specific components (Hyprland, Zsh, UFW, etc.) for detailed troubleshooting.