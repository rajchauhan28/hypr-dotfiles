#!/bin/bash

DIR="$HOME/Pictures/wallpapers/"
WALLS=($(find "$DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" \)))

RANDOMWALL=${WALLS[$RANDOM % ${#WALLS[@]}]}

# Kill any running mpvpaper instances
pkill mpvpaper

# Apply wallpaper with mpvpaper
# "*" = all monitors, replace with e.g. eDP-1 for just one
mpvpaper -o "no-audio --loop --panscan=1.0 --vid=1 --fs" "*" "$RANDOMWALL" &

# Use pywal for colors (uses first frame if video/gif)
wal -i "$RANDOMWALL"

# Reload Alacritty config to apply new colors
alacritty-msg reload

# Restart Waybar to reflect theme changes
pkill waybar
waybar &

