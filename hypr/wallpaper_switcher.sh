#!/bin/bash

# Wallpaper Switcher Script
# Uses swww for static images/GIFs and mpvpaper for videos

WALLPAPER_DIR="$HOME/Pictures/wallpapers/"

# Kill mpvpaper if running
kill_mpvpaper() {
    pkill -9 mpvpaper 2>/dev/null
    sleep 0.3
}

# Initialize swww daemon (only if not running)
init_swww() {
    if ! pgrep -x "swww-daemon" > /dev/null; then
        echo "Starting swww-daemon..."
        swww-daemon &
        sleep 1.5
    fi
}

# Kill swww daemon (for video mode)
kill_swww() {
    swww kill 2>/dev/null
    sleep 0.3
}

# Generate colors with pywal
generate_colors() {
    local wallpaper="$1"
    wal -n -q -i "$wallpaper"
    pkill -SIGUSR2 waybar 2>/dev/null || (pkill waybar 2>/dev/null; waybar &)
}

# Set video wallpaper with mpvpaper
set_video() {
    local file="$1"
    echo "=== Setting VIDEO wallpaper: $(basename "$file") ==="
    
    kill_mpvpaper
    kill_swww
    
    mpvpaper -f -o "no-audio loop hwdec=no cache=no cache-default=no panscan=1" "*" "$file" &
    sleep 1
    
    generate_colors "$file"
    echo "Video wallpaper set successfully"
}

# Set static/GIF wallpaper with swww
set_image() {
    local file="$1"
    echo "=== Setting IMAGE wallpaper: $(basename "$file") ==="
    
    kill_mpvpaper
    init_swww
    
    echo "Setting wallpaper: swww img '$file'"
    swww img "$file" --resize crop --transition-type grow --transition-pos 0.5,0.5 --transition-fps 30 --transition-duration 1
    
    generate_colors "$file"
}

# Main logic
echo "=========================================="
echo "Wallpaper switcher started"

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

# Get file extension (lowercase)
EXT="${RANDOMWALL##*.}"
EXT=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

case "$EXT" in
    mp4|webm|mkv)
        set_video "$RANDOMWALL"
        ;;
    jpg|jpeg|png|gif)
        set_image "$RANDOMWALL"
        ;;
    *)
        echo "ERROR: Unsupported file type: $EXT"
        exit 1
        ;;
esac

echo "Wallpaper applied successfully!"
echo "=========================================="
