#!/bin/bash

# Define paths
CURRENT_THEME_FILE="$HOME/.config/waybar/.current_theme"
THEME_DIR="$HOME/.config/waybar/themes"
CONFIG_FILE="$HOME/.config/waybar/config.jsonc"
STYLE_FILE="$HOME/.config/waybar/style.css"

# Ensure the state file exists
if [ ! -f "$CURRENT_THEME_FILE" ]; then
    echo "standard" > "$CURRENT_THEME_FILE"
fi

# Read current theme
CURRENT=$(cat "$CURRENT_THEME_FILE")

# Determine next theme
if [ "$CURRENT" == "standard" ]; then
    NEXT="alternate"
else
    NEXT="standard"
fi

# Copy the next theme's config and style
cp "$THEME_DIR/$NEXT/config.jsonc" "$CONFIG_FILE"
cp "$THEME_DIR/$NEXT/style.css" "$STYLE_FILE"

# Update the state file
echo "$NEXT" > "$CURRENT_THEME_FILE"

# Reload Waybar to apply changes
# Using SIGUSR2 to reload configuration and style
pkill -SIGUSR2 waybar
