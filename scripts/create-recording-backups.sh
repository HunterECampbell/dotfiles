#!/bin/bash
# Recording Backups - Copies recording-related files to Desktop

BACKUP_DIR="$HOME/Desktop/Recording Backups"

# Remove existing backup directory to ensure clean replacement
rm -rf "$BACKUP_DIR"

# Create directory structure
mkdir -p "$BACKUP_DIR/Shared"
mkdir -p "$BACKUP_DIR/Minecraft Servers"
mkdir -p "$BACKUP_DIR/Game Recordings"

# Copy Shared items
cp -r "$HOME/Shared/Series Goals" "$BACKUP_DIR/Shared/"
cp -r "$HOME/Shared/Thumbnails" "$BACKUP_DIR/Shared/"
cp -r "$HOME/Shared/TODO - Pinned Comments" "$BACKUP_DIR/Shared/"
cp -r "$HOME/Shared/Video Editing Helpers" "$BACKUP_DIR/Shared/"
for f in "$HOME/Shared/"*; do
    if [[ -f "$f" ]] && file --mime-type -b "$f" | grep -q "^text/"; then
        cp "$f" "$BACKUP_DIR/Shared/"
    fi
done

# Copy Minecraft server (selective backup - only essential files for restoration)
GTNH_DIR="$HOME/Minecraft Servers/gtnh"
GTNH_BACKUP="$BACKUP_DIR/Minecraft Servers/gtnh"

# Create Minecraft server backup directory structure
mkdir -p "$GTNH_BACKUP"

# Copy World directory - Contains all world chunks, player data, quests, and mod-specific world data
# This includes: region/ (world chunks), playerdata/ (inventory/character), stats/, betterquesting/ (quests),
# level.dat (world metadata), all DIM* directories (dimensions), and mod data directories
cp -r "$GTNH_DIR/World" "$GTNH_BACKUP/"

# Copy JourneyMap data - Contains map data for all explored areas
cp -r "$GTNH_DIR/journeymap" "$GTNH_BACKUP/"

# Copy server configuration files - Essential for server settings and player management
cp "$GTNH_DIR/server.properties" "$GTNH_BACKUP/"  # Server configuration (port, difficulty, etc.)
cp "$GTNH_DIR/ops.json" "$GTNH_BACKUP/"          # Operator/admin list
cp "$GTNH_DIR/whitelist.json" "$GTNH_BACKUP/"    # Whitelisted players
cp "$GTNH_DIR/usercache.json" "$GTNH_BACKUP/"    # User cache data
cp "$GTNH_DIR/usernamecache.json" "$GTNH_BACKUP/" 2>/dev/null || true  # Username cache (may not exist)
cp "$GTNH_DIR/banned-ips.json" "$GTNH_BACKUP/"   # Banned IP addresses
cp "$GTNH_DIR/banned-players.json" "$GTNH_BACKUP/"  # Banned players

# Copy quest configuration - Contains custom quest data and settings
mkdir -p "$GTNH_BACKUP/config"
cp -r "$GTNH_DIR/config/betterquesting" "$GTNH_BACKUP/config/"  # Quest configuration directory
cp "$GTNH_DIR/config/betterquesting.cfg" "$GTNH_BACKUP/config/" 2>/dev/null || true  # Quest config file (may not exist)

# Copy custom automation scripts - Essential for server functionality
cp "$GTNH_DIR/daylight_monitor.sh" "$GTNH_BACKUP/"  # Custom script that toggles daylight cycle based on player presence
cp "$GTNH_DIR/start.sh" "$GTNH_BACKUP/"             # Server startup script that launches the daylight monitor

# Copy Game Recordings items
cp -r "$HOME/Desktop/Game Recordings/Helpers" "$BACKUP_DIR/Game Recordings/"
for f in "$HOME/Desktop/Game Recordings/"*; do
    if [[ -f "$f" ]] && file --mime-type -b "$f" | grep -q "^text/"; then
        cp "$f" "$BACKUP_DIR/Game Recordings/"
    fi
done

# Copy Music items
cp -r "$HOME/Game Recordings/Music/"* "$BACKUP_DIR/Game Recordings/Music/"