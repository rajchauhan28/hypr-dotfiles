#!/bin/bash

# Screenshot script using grim and slurp
# Usage: screenshot.sh [region|output|active|full]

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"

FILENAME="screenshot_$(date +%Y%m%d_%H%M%S).png"

case "$1" in
    region)
        # Select region with slurp, capture with grim
        grim -g "$(slurp -d -c 00000000 -b 00000000)" "$SCREENSHOT_DIR/$FILENAME"
        ;;
    output)
        # Capture focused output
        grim -o "$(hyprctl activewindow -j | jq -r '.monitor')" "$SCREENSHOT_DIR/$FILENAME"
        ;;
    active)
        # Capture active window
        grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" "$SCREENSHOT_DIR/$FILENAME"
        ;;
    full|*)
        # Capture all outputs
        grim "$SCREENSHOT_DIR/$FILENAME"
        ;;
esac

# Notify and copy to clipboard
if [ -f "$SCREENSHOT_DIR/$FILENAME" ]; then
    wl-copy < "$SCREENSHOT_DIR/$FILENAME"
    notify-send "Screenshot" "Saved to $SCREENSHOT_DIR/$FILENAME"
fi
