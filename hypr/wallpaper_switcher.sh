#!/bin/bash

# 1. Define Directory
DIR="$HOME/Pictures/wallpapers/"

# 2. Dynamic Monitor Detection (Hyprland specific)
# This grabs the name of the first available monitor (e.g., eDP-1, eDP-2, HDMI-A-1)
MONITOR=$(hyprctl monitors -j | jq -r '.[0].name')

# Fallback: If hyprctl isn't available/fails, default to "*" (all monitors)
if [[ -z "$MONITOR" || "$MONITOR" == "null" ]]; then
    MONITOR="*"
fi

# 3. Select Random Wallpaper efficiently
# find handles the extensions; shuf picks one random line
RANDOMWALL=$(find "$DIR" -type f | grep -E "\.(jpg|jpeg|png|gif|mp4|mkv|webm)$" | shuf -n 1)

# 4. Clean up old processes
# Only kill if they are actually running to avoid error noise
pkill -x mpvpaper 2>/dev/null
pkill -x ffmpeg 2>/dev/null

# 5. Apply Wallpaper
# Using an array for arguments is safer and cleaner to read
MPV_OPTS=(
    "--input-ipc-server=/tmp/mpvsocket"
    "hwdec=auto-safe"
    "vo=libmpv"
    "gpu-api=vulkan"
    "profile=fast"
    "loop"
    "panscan=1.0"
)

# Run mpvpaper in background
# ${MPV_OPTS[*]} expands the array into a single string for the -o flag
mpvpaper -o "${MPV_OPTS[*]}" "$MONITOR" "$RANDOMWALL" &

# 6. Generate Colors (Wal)
# -n skips setting the wallpaper (since mpvpaper does it), just generates colors
# -q makes it quiet
wal -n -q -i "$RANDOMWALL"

# 7. Restart Waybar
# Reloading style is often faster/smoother than killing the process
pkill -SIGUSR2 waybar 2>/dev/null || (pkill waybar; waybar &)

echo "Wallpaper set to: $(basename "$RANDOMWALL") on $MONITOR"
