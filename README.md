# My Pop!\_OS Linux Dotfiles

This repository contains my personal configuration files (dotfiles) and setup scripts for a Pop!\_OS Linux environment.

## Table of Contents

1. [Post-Installation Setup](#1-post-installation-setup)
1. [Discord Settings](#2-discord-settings)
1. [FoundryVTT Setup](#3-foundryvtt-setup)
1. [GitHub CLI Setup](#4-github-cli-setup)
1. [GNOME Keybindings Management](#5-gnome-keybindings-management)
1. [Google Messages Setup](#6-google-messages-setup)
1. [Steam Settings](#7-steam-settings)
1. [VPN Setup](#8-vpn-setup)
1. [Zoom Settings](#9-zoom-settings)

## 1. Post-Installation Setup

After a fresh Pop!\_OS Linux install, your entire system can be automatically configured by running a single command. The `bootstrap.sh` script serves as the sole entry point to your self-contained automation. This script will handle all necessary steps, including installing Ansible and its dependencies in a dedicated virtual environment, and then executing the main Ansible playbook to set up your applications, system settings, and dotfiles.

### 1. Make `bootstrap.sh` executable

```
chmod +x ~/Development/repos/dotfiles/scripts/bootstrap.sh
```

### 2. Run `bootstrap.sh`

`bootstrap.sh` can be run in 3 modes:

1. `home` - Adds things used specifically for a home setup (Steam, Minecraft setup, etc.)
1. `work` - Adds things used specifically for a work setup (Slack, Zoom, etc.)
1. `all` - Adds things used in both a home and work setup

You can simply run `bootstrap.sh` and it will prompt for a `home/work/all` choice:

```
~/Development/repos/dotfiles/scripts/bootstrap.sh
```

Or you can run a specific setup:

```
# Home Setup
~/Development/repos/dotfiles/scripts/bootstrap.sh home

# Work Setup
~/Development/repos/dotfiles/scripts/bootstrap.sh work

# All Setup
~/Development/repos/dotfiles/scripts/bootstrap.sh all

## 2. Discord Settings

> [!IMPORTANT]
> Discord settings should automatically be setup when running `bootstrap.sh`. The below are setting references if needed.

You need to turn off Desktop Notifications:

1. Open **Discord** ($SUPER + D)
1. Click your **Profile Picture** -> **Edit Profile**
1. Click **Notifications**
1. Uncheck **Enable Desktop Notifications**

For a virtual background, follow this guide: [Discord Virtual Background Setup](../discord-virtual-background-setup.md)

## 3. FoundryVTT Setup

> [!IMPORTANT]
> FoundryVTT should not be automatically downloaded/setup, because it uses a **Purchased License** to validate ownership. Adding an automatic download/setup will make the license public, which is not what we want.

### Downloading FoundryVTT

1. Go to Foundry's [Install](https://foundryvtt.com/article/installation/) page
1. Follow their instructions

### No IP

When setting up a live server, it uses your machine's IP Address as the Browser's URL. We want to hide this IP so players don't access your IP directly. You can setup a hidden IP via [No IP](https://www.noip.com/login). No IP essentially creates a different browser URL that will point to your IP (e.g. my-random-name.ddns.net:30000 - 30000 is the default FoundryVTT port).

## 4. GitHub CLI Setup

For seamless interaction with GitHub from your terminal (e.g., `git push`, `git pull` without password prompts), it's highly recommended to set up `github-cli` (`gh`).

Refer to the dedicated guide: [github-cli-setup.md](./github-cli-setup.md)

## 5. GNOME Keybindings Management

A full snapshot of GNOME keybindings is applied by the Ansible role `gnome-settings` using:
`ansible/roles/gnome-settings/vars/keybindings.yml`

### To Update Keybinds

1. Change keybindings in GNOME as desired.
1. You will need to be in the repo to run the below command to regenerate keybindings:
```

./scripts/export_gnome_keybindings.sh

````
- If you need to make the script executable (it should already be executable if you run the `bootstrap.sh`):
  ```
  chmod +x ./scripts/export_gnome_keybindings.sh
  ```
1. Script actions:
- Rebuilds the vars file with window manager, media-keys, shell, mutter (if present), and custom keybindings
- Stages the updated vars file (you will still need to commit)
- It will prompt you to optionally apply the keybind settings immediately. You can also manually apply the settings via:
  ```
  ansible-playbook ansible/playbook.yml --tags gnome-settings
  ```

## 6. Google Messages Setup

This is so you can use the phone keybind ($SUPER + P).

Set up browser texting at: [Google Messages Web](https://messages.google.com/web)

## 7. Steam Settings

> [!IMPORTANT]
> Steam settings should automatically be setup when running `bootstrap.sh`. The below are setting references if needed.

### For faster steam load times, make sure to follow these steps:

1. Open **Steam**
1. Go to **Steam** (top-left corner) -> **Settings**
1. Navigate to the **Interface** tab.
1. Make sure the box that says **"Enable GPU accelerated rendering in web views"** is **checked**.
1. Click **OK** and **restart Steam**.

## 8. VPN Setup

1. Go to Notion and search VPN Linux
1. Follow the video guide

Follow the steps at work to finish your VPN setup

## 9. Zoom Settings

> [!IMPORTANT]
> Zoom settings should automatically be setup when running `bootstrap.sh`. The below are setting references if needed.

### Audio & Video Settings

Check the following settings:

- Microphone
- Audio Output (Headset)
- Camera
- Virtual Background

### Additional Settings

- General -> Turn Off **"Change status to 'Away' when inactive for:"**
- Audio -> Audio Profile -> Select **"Personalized audio isolation"**
- Meetings & webinars -> Join Experience -> Select **"Show video preview first"**
- Meetings & webinars -> Join Experience -> Select **"Keep my camera off"**
- Meetings & webinars -> My Video -> Select **"Show me as an active speaker when I talk"**
- Meetings & webinars -> Controls -> Select **"Keep meeting controls visible**
````
