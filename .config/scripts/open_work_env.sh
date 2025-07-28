#!/bin/bash

CHROME_CMD="google-chrome-stable --profile-directory=\"Profile 1\""
DISCORD_CMD="discord"
SLACK_CMD="slack"
CISCO_CMD="/opt/cisco/secureclient/bin/vpnui"

hyprctl_dispatch() {
    hyprctl dispatch "$@"
}

# 1. Go to Workspace 1 and open Google Chrome
hyprctl_dispatch workspace 1
hyprctl_dispatch exec "$CHROME_CMD"
sleep 3

# 2. Go to Workspace 11, open Discord, then Slack
hyprctl_dispatch workspace 11
hyprctl_dispatch exec "$DISCORD_CMD"
sleep 3
hyprctl_dispatch exec "$SLACK_CMD"
sleep 3

# 3. Go to Workspace 3, open terminal, run 'repo vac && c', go to Workspace 2
hyprctl_dispatch workspace 3
hyprctl_dispatch exec "kitty"
sleep 3
hyprctl_dispatch exec "wtype $'repo vac && c\n'"
sleep 0.1
hyprctl_dispatch workspace 2
sleep 3

# 4. Open a second terminal in Workspace 2 and run 'repo vac && rd'
hyprctl_dispatch workspace 3
hyprctl_dispatch exec "kitty"
sleep 3
hyprctl_dispatch exec "wtype $'repo vac && rd\n'"
sleep 0.1

# 5. Go to Workspace 10 and open Cisco Secure Client
hyprctl_dispatch workspace 10
hyprctl_dispatch exec "$CISCO_CMD"