# My Arch Linux Dotfiles

This repository contains my personal configuration files (dotfiles) and setup scripts for an Arch Linux environment, specifically tailored for Hyprland.

## Table of Contents

1. [Initial Arch Linux Installation](#1-initial-arch-linux-installation)
1. [Post-Installation Setup](#2-post-installation-setup)
    - [Cloning the Dotfiles Repository](#cloning-the-dotfiles-repository)
    - [Symlinking Dotfiles](#symlinking-dotfiles)
    - [Running Setup Scripts](#running-setup-scripts)
1. [Chrome Setup](#3-chrome-setup)
1. [Discord Settings](#4-discord-settings)
1. [GitHub CLI Setup](#5-github-cli-setup)
1. [Steam Settings](#6-steam-settings)
1. [VPN Setup](#7-vpn-setup)
1. [Zoom Settings](#8-zoom-settings)
1. [Important Notes](#9-important-notes)

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

Open up a new terminal with $SUPER + W (This is the default binding, it will change to $Super + T once you use this custom setup.)  $SUPER is the Windows key on Windows.

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

# Create symlinks from your dotfiles repo to your home directory. Here are the symlinks you need:
ln -s ~/dotfiles/.config/hypr ~/.config/hypr
ln -s ~/dotfiles/.config/scripts ~/.config/scripts
ln -s ~/dotfiles/.config/waybar ~/.config/waybar
ln -s ~/dotfiles/.config/zoomus.conf ~/.config/zoomus.conf
ln -s ~/dotfiles/.zshrc ~/.zshrc

# Run this command to update your local applications
update-desktop-database ~/.local/share/applications/

# Run these commands to get this to start
chmod +x ~/.config/scripts/run_all_scripts.sh
chmod +x ~/.config/scripts/record_screen.sh
sudo systemctl enable --now NetworkManager.service
sudo systemctl start docker.service
sudo systemctl enable docker.service
sudo usermod -aG docker $USER
newgrp docker
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

## 3. Chrome Setup

To open personal vs work accounts, follow these steps:

1. Open **Google Chrome** and go to **chrome://version**
1. Find the **Profile Path** value and copy it
1. Go to your `~/.config/hypr/hyprland.conf` and find the binding section
    - There should be some commented out bindings for **Personal** and **Work** Chrome profiles
    - Edit these bindings to use the two different profiles
1. Remove the default binding and uncomment the new ones

To help apps to use Wayland:

1. Open **Google Chrome** and go to **chrome://flags**
1. Search for **ozone**
1. Select **Wayland**

## 4. Discord Settings

You need to turn off Desktop Notifications:

1. Open **Discord** ($SUPER + D)
1. Click your **Profile Picutre** -> **Edit Profile**
1. Click **Notifications**
1. Uncheck **Enable Desktop Notifications**

## 5. GitHub CLI Setup

For seamless interaction with GitHub from your terminal (e.g., `git push`, `git pull` without password prompts), it's highly recommended to set up `github-cli` (`gh`).

Refer to the dedicated guide: [github-cli-setup.md](./github-cli-setup.md)

## 6. Steam Settings

For faster steam load times, make sure to follow these steps:

1. Open **Steam** (This will usually take a second if it's loading for the first time during a login session).
1. Go to **Steam** (top-left corner) -> **Settings**
1. Navigate to the **Interface** tab.
1. Make sure the box that says **"Enable GPU accelerated rendering in web views"** is **checked**.
1. Click **OK** and **restart Steam**.

## 7. VPN Setup

1. Open **Advanced Network Configuration** via the menu ($Super + M)
1. Click the **+** button
1. Select a VPN Service
1. Follow the steps at work to finish setup from here

## 8. Zoom Settings

Zoom needs some settings turned on for screen sharing:

1. Open **Zoom** and login
1. Open the **Settings** by clicking on the **Cog Icon**
1. Click **Screen Sharing**
1. Scroll down and click **Advanced**
1. For the **Screen capture mode on Wayland** dropdown, select **Pipewire Mode**
1. Enable **Use TCP connection for screen sharing**

**Make sure your audio and video is using the correct:**

- Microphone
- Audio Output (Headset)
- Camera

**Add a virtual background**

## 9. Important Notes

- **Reboot/Relogin:** After running the setup scripts, it's often necessary to reboot your system or log out and log back in for all changes (especially shell changes and display manager configurations) to take full effect.

- **Customization:** These dotfiles reflect my personal preferences. Feel free to modify them to suit your needs!

- **Troubleshooting:** If you encounter issues, check the output of the `run_all_scripts.sh` script for error messages. Consult the Arch Wiki for specific components (Hyprland, Zsh, UFW, etc.) for detailed troubleshooting.