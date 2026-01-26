#!/bin/bash
# Recording Backups - Copies recording-related files to Desktop

BACKUP_DIR="$HOME/Desktop/Recording Backups"

# Remove existing backup directory to ensure clean replacement
rm -rf "$BACKUP_DIR"

# Create directory structure
mkdir -p "$BACKUP_DIR/Shared"
mkdir -p "$BACKUP_DIR/Minecraft Servers"
mkdir -p "$BACKUP_DIR/Game Recordings"
mkdir -p "$BACKUP_DIR/Game Recordings/Music"

# Copy Shared items
cp -r "$HOME/Shared/Thumbnails" "$BACKUP_DIR/Shared/"
cp -r "$HOME/Shared/Video Editing Helpers" "$BACKUP_DIR/Shared/"
for f in "$HOME/Shared/"*; do
    if [[ -f "$f" ]] && file --mime-type -b "$f" | grep -q "^text/"; then
        cp "$f" "$BACKUP_DIR/Shared/"
    fi
done

# Copy Minecraft server
cp -r "$HOME/Minecraft Servers/gtnh" "$BACKUP_DIR/Minecraft Servers/"

# Copy Game Recordings items
cp -r "$HOME/Desktop/Game Recordings/Helpers" "$BACKUP_DIR/Game Recordings/"
for f in "$HOME/Desktop/Game Recordings/"*; do
    if [[ -f "$f" ]] && file --mime-type -b "$f" | grep -q "^text/"; then
        cp "$f" "$BACKUP_DIR/Game Recordings/"
    fi
done

# Copy Music items
cp -r "$HOME/Game Recordings/Music/"* "$BACKUP_DIR/Game Recordings/Music/"