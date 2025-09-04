# Discord Virtual Camera Setup

Discord does not provide virtual backgrounds on Linux devices. This guide will help you setup a virtual camera that will use a virtual background that can be used in Discord.

## 1. Necessary packages

Make sure these packages are installed. They should be installed with the `run_all_scripts.sh` by using the `Home` option.

```
sudo pacman -S obs-studio v4l2loopback-dkms linux-headers
yay -S yay -S obs-backgroundremoval # Uses AI to remove your background without a green screen.
```

## 2. Setup `v4l2loopback`

> [!IMPORTANT]
> Since this affects the `/etc/` directory, we will not use a script to setup the virtual camera. The necessary configs are included in this repo and need to be copied to the `/etc/` directory.

> [!IMPORTANT]
> THIS WON'T WORK!
> We lost these files to the arch repo setup that was removed. We need to reset this up.

After installing the necessary packages, run these commands to load and setup `v4l2loopback` so you can create a virtual camera:

```
sudo modprobe v4l2loopback devices=1 video_nr=20 card_label="OBS Virtual Camera" exclusive_caps=1
sudo cp ~/Development/repos/dotfiles/etc/modprobe.d/v4l2loopback.conf /etc/modprobe.d
sudo cp ~/Development/repos/dotfiles/etc/modprobe.d/v4l2loopback.conf /etc/modprobe.d
```

## 3. Configure OBS Studio

Launch OBS Studio (You can launch it via your menu with $SUPER + M)

### 1. Setup Your Camera

1. In the **"Sources"** section, click the `+` button and choose **"Video Capture Device (V4L2)"**
1. Right click on your new Video Capture Device
1. Select **"Filters"**
1. Click the `+` button and select "Background Removal"
1. Adjust settings as desired

### 2. Setup Your Virtual Background

1. Go back to your **"Sources"**, click the `+` button and choose **"Media Source"**
1. Choose **"Image"** for a static image, or **"Media Source"** for a video
1. Browse for your desired image or video file

> [!IMPORTANT]
> In your "Sources", drag this new "Media Source" below the "Video Capture Device (V4L2)"

## 4. Start the Virtual Camera

Whenever you want to use your virtual background in Discord, you need to start the Virtual Camera in OBS Studio.

- In the main view of OBS Studio, click **"Start Virtual Camera"**

## 5. Use the Virtual Camera in Discord

1. In Discord, open your User Settings by clicking on the **cog** icon
1. In the sidebar, click **"Voice & Video"**
1. Go to the **"Video"** tab
1. In the **"Camera"** dropdown, select **"OBS Virtual Camera"**
1. Enable **"Always preview video"**
