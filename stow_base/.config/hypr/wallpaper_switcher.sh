#!/bin/bash

# Walllust Wallpaper Switcher
# Delegating all logic to walllust-daemon which handles:
# - Native image transitions (fade, slide, grow, zoom)
# - Video wallpaper fallback (mpvpaper)
# - Pywal color generation

# walllust is not packaged; it is a separate binary the user installs into
# ~/.local/bin. Without it there is simply no wallpaper daemon to talk to, and
# an exec-once that errors on every login is worse than one that opts out.
if ! command -v walllust-cli >/dev/null 2>&1; then
    echo "walllust-cli not found; skipping wallpaper rotation."
    exit 0
fi

# Wait for walllust-daemon to fully initialize on startup
sleep 2

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
walllust-cli set "$RANDOMWALL"

# Wait for walllust-daemon to finish generating colors
sleep 0.5
echo "Wallpaper applied successfully via walllust!"
