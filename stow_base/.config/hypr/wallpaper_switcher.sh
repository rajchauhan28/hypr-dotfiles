#!/bin/bash

# Walllust Wallpaper Switcher
# Delegating all logic to walllust-daemon which handles:
# - Native image transitions (fade, slide, grow, zoom)
# - Video wallpaper fallback (mpvpaper)
# - Pywal color generation

WALLPAPER_DIR="$HOME/Pictures/wallpapers/"

if [ ! -d "$WALLPAPER_DIR" ]; then
    echo "ERROR: Wallpaper directory not found: $WALLPAPER_DIR"
    exit 1
fi

# Pick random wallpaper
RANDOMWALL=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" \) | shuf -n 1)

if [ -z "$RANDOMWALL" ]; then
    echo "ERROR: No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

echo "Selected: $RANDOMWALL"

# Apply via walllust-cli
# We use the default transition configured in the daemon
walllust-cli set "$RANDOMWALL"

# Signal waybar to refresh (since daemon doesn't do this yet)
pkill -SIGUSR2 waybar 2>/dev/null

echo "Wallpaper applied successfully via walllust!"
