#!/bin/bash
# This script backs up specified configuration directories to a backup folder.

# The directory where the backup will be stored.
BACKUP_DIR="/home/reign/hypr-dotfiles"

# An array of directories to back up.
CONFIG_DIRS=(
    "$HOME/.config/hypr"
    "$HOME/.config/swaync"
    "$HOME/.config/waybar"
    "$HOME/.config/yazi"
    "$HOME/.config/ghostty"
    "$HOME/.config/rofi"
    "$HOME/.config/wofi"
    "$HOME/.config/wlogout"
    "$HOME/.config/ReignShell"
    "$HOME/.config/nvim"
    "$HOME/.config/mpv"
)

# Create the backup directory if it does not already exist.
mkdir -p "$BACKUP_DIR"

# Loop through each directory in the CONFIG_DIRS array and copy it to the backup location.
for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        cp -r "$dir" "$BACKUP_DIR"
        echo "Backed up $dir to $BACKUP_DIR"
    else
        echo "Warning: Directory $dir does not exist, skipping."
    fi
done

echo "Backup process completed."
