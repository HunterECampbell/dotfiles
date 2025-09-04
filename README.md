# My Pop!\_OS Linux Dotfiles

This repository contains my personal configuration files (dotfiles) and setup scripts for a Pop!\_OS Linux environment.

## Table of Contents

1. [Post-Installation Setup](#1-post-installation-setup)
1. [Chrome Setup](#2-chrome-setup)
1. [Discord Settings](#3-discord-settings)
1. [FoundryVTT Setup](#4-foundryvtt-setup)
1. [GitHub CLI Setup](#5-github-cli-setup)
1. [Google Messages Setup](#6-google-messages-setup)
1. [Steam Settings](#7-steam-settings)
1. [VPN Setup](#8-vpn-setup)
1. [Zoom Settings](#9-zoom-settings)

## 1. Post-Installation Setup

After a fresh Pop!\_OS Linux install, your entire system can be automatically configured by running a single command. The `bootstrap.sh` script serves as the sole entry point to your self-contained automation. This script will handle all necessary steps, including installing Ansible and its dependencies in a dedicated virtual environment, and then executing the main Ansible playbook to set up your applications, system settings, and dotfiles.

Follow these steps to get started:

### 1. Run `bootstrap.sh`

Execute the `bootstrap.sh` script to begin the automated setup. This command will prompt you for your `sudo` password to perform system-level tasks.

```
chmod +x ~/Development/repos/dotfiles/scripts/bootstrap.sh
~/Development/repos/dotfiles/scripts/bootstrap.sh
```

## 2. Chrome Setup

To open personal vs work accounts, follow these steps:

1. Open **Google Chrome** and go to **chrome://version**
1. Find the **Profile Path** value and copy it
1. Go to your `~/.config/hypr/hyprland.conf` and find the binding section
   - There should be some commented out bindings for **Personal** and **Work** Chrome profiles
   - Edit these bindings to use the two different profiles
1. Remove the default binding and uncomment the new ones

## 3. Discord Settings

You need to turn off Desktop Notifications:

1. Open **Discord** ($SUPER + D)
1. Click your **Profile Picture** -> **Edit Profile**
1. Click **Notifications**
1. Uncheck **Enable Desktop Notifications**

For a virtual background, follow this guide: [Discord Virtual Background Setup](../discord-virtual-background-setup.md)

## 4. FoundryVTT Setup

> [!IMPORTANT]
> FoundryVTT should not be automatically downloaded/setup, because it uses a **Purchased License** to validate ownership. Adding an automatic download/setup will make the license public, which is not what we want.

### Downloading FoundryVTT

1. Go to Foundry's [Install](https://foundryvtt.com/article/installation/) page
1. Follow their instructions

### No IP

When setting up a live server, it uses your machine's IP Address as the Browser's URL. We want to hide this IP so players don't access your IP directly. You can setup a hidden IP via [No IP](https://www.noip.com/login). No IP essentially creates a different browser URL that will point to your IP (e.g. my-random-name.ddns.net:30000 - 30000 is the default FoundryVTT port).

## 5. GitHub CLI Setup

For seamless interaction with GitHub from your terminal (e.g., `git push`, `git pull` without password prompts), it's highly recommended to set up `github-cli` (`gh`).

Refer to the dedicated guide: [github-cli-setup.md](../github-cli-setup.md)

## 6. Google Messages Setup

To use the phone keybind ($SUPER + P)

Setup browser texting at: [Google Messages Web](https://messages.google.com/web)

## 7. Steam Settings

### For faster steam load times, make sure to follow these steps:

1. Open **Steam** (This will usually take a second if it's loading for the first time during a login session).
1. Go to **Steam** (top-left corner) -> **Settings**
1. Navigate to the **Interface** tab.
1. Make sure the box that says **"Enable GPU accelerated rendering in web views"** is **checked**.
1. Click **OK** and **restart Steam**.

## 8. VPN Setup

Follow the steps at work to finish setup from here

1. Go to Notion and search VPN Linux
1. Follow the video guide

## 9. Zoom Settings

### Audio & Video Settings

Check the following settings:

- Microphone
- Audio Output (Headset)
- Camera
- Virtual Background

### Additional Settings:

- General -> Turn Off **"Change status to 'Away' when inactive for:"**
- Audio -> Audio Profile -> Select **"Personalized audio isolation"**
- Meetings & webinars -> Join Experience -> Select **"Show video preview first"**
- Meetings & webinars -> Join Experience -> Select **"Keep my camera off"**
- Meetings & webinars -> My Video -> Select **"Show me as an active speaker when I talk"**
- Meetings & webinars -> Controls -> Select **"Keep meeting controls visible**
