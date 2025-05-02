#!/bin/bash

# Directory paths
WALL_DIR="$HOME/wallpapers"
WAYBAR_DIR="$HOME/.config/waybar"
TERMINAL_CONFIG="$HOME/.config/alacritty/alacritty.toml" # or kitty.conf

# Pick a random wallpaper
WALL=$(find "$WALL_DIR" -type f | shuf -n 1)

# Set wallpaper (using swww)
swww img "$WALL" --transition-type grow --transition-duration 1

# Extract theme name from wallpaper filename (e.g., "nord.jpg" → "nord")
THEME=$(basename "$WALL" | cut -d. -f1)

# Apply Waybar theme
if [ -f "$WAYBAR_DIR/themes/$THEME.css" ]; then
    ln -sf "$WAYBAR_DIR/themes/$THEME.css" "$WAYBAR_DIR/style.css"
    pkill -SIGUSR2 waybar
fi

# Apply Alacritty theme
if [ -f "$HOME/.config/alacritty/themes/$THEME.toml" ]; then
    sed -i "s#import.*#import = [\"themes\/$THEME.toml\"]#" "$TERMINAL_CONFIG"
    pkill -USR1 alacritty
fi

notify-send "🖼️ Theme switched to $THEME"
