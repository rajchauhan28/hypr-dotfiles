#!/bin/bash

TITLE=$(playerctl metadata title 2>/dev/null)
ARTIST=$(playerctl metadata artist 2>/dev/null)
ALBUM=$(playerctl metadata album 2>/dev/null)
ARTURL=$(playerctl metadata mpris:artUrl 2>/dev/null)
PLAYER=$(playerctl -l 2>/dev/null | head -n 1)
ICON="/usr/share/icons/hicolor/128x128/apps/multimedia-player.png"

# Fallback values
TITLE=${TITLE:-"Unknown Title"}
ARTIST=${ARTIST:-"Unknown Artist"}
ALBUM=${ALBUM:-""}
PLAYER=${PLAYER:-"Media Player"}

# Download album art if available
if [[ $ARTURL == http* ]]; then
    wget -qO /tmp/album_art.jpg "$ARTURL"
    ICON="/tmp/album_art.jpg"
fi

# Notification body
BODY="$TITLE\n$ARTIST"
[[ -n "$ALBUM" ]] && BODY="$BODY\n$ALBUM"

# Send notification with dunstify
dunstify -a "$PLAYER" -i "$ICON" "🎵 Now Playing" "$BODY"
