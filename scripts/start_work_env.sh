# Open Chrome
flatpak run com.google.Chrome --profile-directory="Profile 2" &

# Open Discord and Slack
flatpak run com.discordapp.Discord &
slack &
sleep 3

# Setup Code via the Terminal
gnome-terminal &
sleep 3
# Run FE Server
xdotool keydown Control_L+Shift_L+t
xdotool keyup Control_L+Shift_L+t
sleep 1
xdotool type "repo vac && prd"
xdotool key KP_Enter
sleep 1
xdotool keydown Control+Page_Up
xdotool keyup Control+Page_Up
sleep 1
# Open Repo
xdotool type "repoc vac"
xdotool key KP_Enter
sleep 3

# Open Cisco AnyConnect
/opt/cisco/secureclient/bin/vpnui