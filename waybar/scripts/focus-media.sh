#!/bin/bash

# Get first active media player
PLAYER=$(playerctl -l 2>/dev/null | head -n 1)
if [ -z "$PLAYER" ]; then
    notify-send "🎵 No media player is running"
    exit 1
fi

# Try to extract a window class from the player name
# Fallback to known apps
case "$PLAYER" in
    spotify)
        REGEX="Spotify"
        ;;
    vlc)
        REGEX="VLC"
        ;;
    firefox|chromium|brave)
        REGEX="(Firefox|Chromium|Brave)"
        ;;
    mpv)
        REGEX="mpv"
        ;;
    *)
        # Fallback: try playerctl title (may not work always)
        TITLE=$(playerctl metadata title 2>/dev/null)
        REGEX="$TITLE"
        ;;
esac

# Focus using hyprctl
hyprctl dispatch focuswindow "$REGEX" || notify-send "⚠️ Could not find window for: $PLAYER"
