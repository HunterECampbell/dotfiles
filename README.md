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
1. [FoundryVTT Setup](#5-foundryvtt-setup)
1. [GitHub CLI Setup](#6-github-cli-setup)
1. [Steam Settings](#7-steam-settings)
1. [VPN Setup](#8-vpn-setup)
1. [Zoom Settings](#9-zoom-settings)
1. [Important Notes](#10-important-notes)

## 1. Initial Arch Linux Installation

Run `archinstall`

> [!TIP]
> You can search with `/`

Use the following settings for a smooth dotfiles setup:

### Mirrors and Repositories:

- Select **Regions**
  - Select **United States**
- Select **Optional repositories**
  - Select **multilib**

### Disk Configuartion

- Select **Partitioning**
  - Select **Use a best-effort default partitioning layout**
- Select **Partitioning Layout**
  - Select **Select storage device**
    - Select **ext4**
      - Select **No** for creating a separate `/home` directory
- Select **Partition**
  - Select **Disk Encryption**
    - Select **LUKS**
    - Select **Encryption password**
      - This is the password you will use to start up Arch Linux
    - Select **Partitions**
      - Select the partition you created

### Hostname

- Add whatever you like for a hostname

### Authentication

#### Root Password

- Add a root password

#### User Account

- Select **Account**
  - Select **Add a user**
    - Fill out a username and password
  - Make them a `sudo` user

### Profile

- Select **Type**
  - Select whichever type you like (e.g. **Desktop**)
    - Select **Hyprland**
      - Select **Polkit**
  - Select **Graphic Drivers**
    - Select **Nvidia (proprietary)**

### Audio

- Select **Pulseaudio**

### Network Configuration

- Select **NetworkManager**

### Timezone

- Select a timezone (US/Mountain)

### Finalization

> [!TIP]
> You won't need to select any additional packages, as the following steps will have you run a script to download all necessary packages automatically.

> [!IMPORTANT]
> Prepare to remove your USB (Don't do it yet!). You will want to remove the USB once the system powers down, not while it's in the process of powering down.

Finish up by installing. Once the install is complete, select **Reboot**

## 2. Post-Installation Setup

After a fresh Arch Linux install, follow the below steps.

### Cloning the Dotfiles Repository

Open up a new terminal with $SUPER + Q (This is the default binding, it will change to $SUPER + T once you use this custom setup.) $SUPER is the Windows key on Windows.

> [!IMPORTANT]
> You will need an internet connection to continue. Run `nmcli` to check that you are connected to the internet.

First, create and go to your repos directory:

```
mkdir -p ~/Development/repos
cd ~/Development/repos
```

Then, clone this repository to your repos directory:

```
git clone https://github.com/HunterECampbell/dotfiles.git ~/dotfiles
```

### Symlinked Dotfiles

This repository uses symbolic links to manage dotfiles. This means the configuration files you edit will live in `~/Development/repos/dotfiles/`, and the symlinks will point from these dotfiles to their traditional locations (e.g., `~/.config`). Symlinks are automatically setup in the below script (`~/Development/repos/dotfiles/.config/scripts/run_setup_scripts.sh`).

### Running Setup Scripts

This setup script handles all setup tasks, from package installations to configuring systemd user services. **It must be run from its source location first.**

#### 1. Run the master script:

This command will run the master script, which in turn will set up all symlinks and execute the rest of your setup scripts (for package installations, Zsh setup, UFW configuration, etc.). Scripts that require elevated privileges will prompt you for your sudo password.

```
~/Development/repos/dotfiles/.config/scripts/run_setup_scripts.sh
```

#### 2. Using the symlinked script (after initial run):

Once the setup script has been run once, the symlink will exist, and you can use the more convenient path for any future runs.

```
~/.config/scripts/run_setup_scripts.sh
```

> [!NOTE]
> Pay attention to the output. If any setup script fails, the master script will report it at the end.

#### 3. Restart your computer

For all changes to take effect, it is best to restart your computer.

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
1. Click your **Profile Picture** -> **Edit Profile**
1. Click **Notifications**
1. Uncheck **Enable Desktop Notifications**

## 5. FoundryVTT Setup

> [!IMPORTANT]
> FoundryVTT should not be automatically downloaded/setup, because it uses a **Purchased License** to validate ownership. Adding an automatic download/setup will make the license public, which is not what we want.

### Downloading FoundryVTT

1. Go to Foundry's [Install](https://foundryvtt.com/article/installation/) page
1. Follow their instructions

### No IP

When setting up a live server, it uses your machine's IP Address as the Browser's URL. We want to hide this IP so players don't access your IP directly. You can setup a hidden IP via [No IP](https://www.noip.com/login). No IP essentially creates a different browser URL that will point to your IP (e.g. my-random-name.ddns.net:30000 - 30000 is the default FoundryVTT port).

## 6. GitHub CLI Setup

For seamless interaction with GitHub from your terminal (e.g., `git push`, `git pull` without password prompts), it's highly recommended to set up `github-cli` (`gh`).

Refer to the dedicated guide: [github-cli-setup.md](./github-cli-setup.md)

## 7. Steam Settings

For faster steam load times, make sure to follow these steps:

1. Open **Steam** (This will usually take a second if it's loading for the first time during a login session).
1. Go to **Steam** (top-left corner) -> **Settings**
1. Navigate to the **Interface** tab.
1. Make sure the box that says **"Enable GPU accelerated rendering in web views"** is **checked**.
1. Click **OK** and **restart Steam**.

To use a separate SSD for gaming, follow these steps:

1. If you have a dedicated (separate) ssd and haven't already, run the `~/.config/scripts/setup_scripts/setup_gaming_ssd.sh
1. Go to **Steam** (top-left corner) -> **Settings**
1. Navigate to the **Storage** tab.
1. Click "+ Add Drive"
1. Select the SSD
1. Open the dropdown for the drives
1. Select the new drive
1. Open the 3 dot menu
1. Select "Make Default"

## 8. VPN Setup

Follow the steps at work to finish setup from here

1. For Cisco AnyConnect, make sure you have `openconnect`, `networkmanager-openconnect`, and `webkit2gtk` installed
1. Go to Notion and search VPN Linux
1. Follow the video guide

## 9. Zoom Settings

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

## 10. Important Notes

- **Reboot/Relogin:** After running the setup scripts, it's often necessary to reboot your system or log out and log back in for all changes (especially shell changes and display manager configurations) to take full effect.

- **Customization:** These dotfiles reflect my personal preferences. Feel free to modify them to suit your needs!

- **Troubleshooting:** If you encounter issues, check the output of the `run_setup_scripts.sh` script for error messages. Consult the Arch Wiki for specific components (Hyprland, Zsh, UFW, etc.) for detailed troubleshooting.
