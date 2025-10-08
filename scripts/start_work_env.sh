# Start Applications
flatpak run com.google.Chrome --profile-directory="Profile 2" &
flatpak run com.discordapp.Discord &
slack &
/opt/cisco/secureclient/bin/vpnui
sleep 5

# Start Terminal
kitty &
sleep 3
xdotool type "attach vac"
xdotool key KP_Enter