#!/bin/bash

# Define Directory
DIR="$HOME/Pictures/wallpapers/"

# Check if swww-daemon is running, if not start it
if ! pgrep -x "swww-daemon" > /dev/null; then
    swww-daemon &
    sleep 0.5
fi

# Select Random Wallpaper
RANDOMWALL=$(find "$DIR" -type f | grep -E "\.(jpg|jpeg|png|gif)$" | shuf -n 1)

if [ -z "$RANDOMWALL" ]; then
    echo "No wallpapers found in $DIR"
    exit 1
fi

# Apply Wallpaper with swww (smooth transition)
swww img "$RANDOMWALL" --transition-type grow --transition-pos 0.5,0.5 --transition-fps 60 --transition-duration 2

# Generate Colors (Wal)
wal -n -q -i "$RANDOMWALL"

# Reload Waybar to apply new colors
pkill -SIGUSR2 waybar 2>/dev/null || (pkill waybar; waybar &)

echo "Wallpaper set to: $(basename "$RANDOMWALL")"