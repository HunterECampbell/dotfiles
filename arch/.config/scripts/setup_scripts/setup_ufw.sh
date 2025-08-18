#!/bin/bash

# Script to set up UFW (Uncomplicated Firewall) with basic rules.
# This script assumes UFW is already installed.
# If UFW is not installed, run: sudo pacman -S ufw
#
# IMPORTANT: Run this script with sudo:
# sudo ./setup_ufw.sh

echo "Starting UFW setup..."

# Check if UFW is installed
if ! command -v ufw &> /dev/null
then
    echo "UFW is not installed. Attempting to install UFW..."
    sudo pacman -S ufw --noconfirm # --noconfirm to avoid manual 'y' prompt(s)
    if [ $? -ne 0 ]; then
        echo "Failed to install UFW. Please check your package manager and try again."
        exit 1
    else
        echo "UFW installed successfully."
    fi
fi

# 1. Enable and Start the UFW Service
echo "Enabling and starting UFW service..."
sudo systemctl enable ufw.service
sudo systemctl start ufw.service

# Check if the service started successfully
if systemctl is-active --quiet ufw.service; then
    echo "UFW service is active and enabled on boot."
else
    echo "Failed to start UFW service. Exiting."
    exit 1
fi

# 2. Set Default Policies
echo "Setting default UFW policies: denying incoming, allowing outgoing."
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 3. Allow specific incoming ports for port forwarding
# You can customize this array with ports you need to open.
# For SSH, it's generally recommended to allow it if you need remote access.
# UFW can recognize common service names like 'ssh'.

# Define an array of ports/services to allow
# Example: "22/tcp" for SSH, "80/tcp" for HTTP, "443/tcp" for HTTPS
# Including ports 80/tcp and 443/tcp for development
# Including port 25565/tcp for Minecraft servers
# Including port 30000/tcp for FoundryVTT
declare -a ALLOW_PORTS=("80/tcp" "443/tcp" "25565/tcp", "30000/tcp")

echo "Adding specific ALLOW rules for incoming traffic:"
for port_rule in "${ALLOW_PORTS[@]}"; do
    echo "  - Allowing incoming traffic on port/service: $port_rule"
    sudo ufw allow "$port_rule"
done

# 4. Enable UFW
# This command will prompt for confirmation if UFW is not already active.
echo "Enabling UFW. You may be prompted to confirm."
sudo ufw enable

# Check if UFW is active after enabling
if sudo ufw status | grep -q "Status: active"; then
    echo "UFW is now active and enabled on system startup."
else
    echo "Failed to enable UFW. Please check for errors."
    exit 1
fi

# 5. Display UFW Status
echo -e "\n--- UFW Status ---"
sudo ufw status verbose
echo "------------------"

echo "UFW setup complete!"
