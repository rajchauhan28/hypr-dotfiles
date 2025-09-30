#!/bin/bash

DIR="$HOME/Pictures/wallpapers/"
WALLS=($(find "$DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" \)))

RANDOMWALL=${WALLS[$RANDOM % ${#WALLS[@]}]}

# Kill any running mpvpaper instances
pkill mpvpaper

# Apply wallpaper with mpvpaper
# "*" = all monitors, replace with e.g. eDP-1 for just one
# mpvpaper -o "no-audio --loop --panscan=1.0 --vid=1 --fs" "*" "$RANDOMWALL" &
mpvpaper -o "--input-ipc-server=/tmp/mpvsocket hwdec=auto-safe vo=libmpv gpu-api=vulkan profile=fast video-sync=display-resample interpolation tscale=oversample --loop --panscan=1.0" "eDP-1" "$RANDOMWALL" &
# Use pywal for colors (uses first frame if video/gif)
wal -i "$RANDOMWALL"



# Restart Waybar to reflect theme changes
pkill waybar
waybar &
pkill ffmpeg
pkill ffmpeg
pkill ffmpeg
pkill ffmpeg
