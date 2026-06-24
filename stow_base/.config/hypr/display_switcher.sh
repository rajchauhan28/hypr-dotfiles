#!/bin/bash

# Define monitor names (Edit these if they change)
INTERNAL="eDP-1"
EXTERNAL="HDMI-A-1"

# Options
OPT_EXTEND_R="Extend (Right)"
OPT_EXTEND_L="Extend (Left)"
OPT_MIRROR="Mirror"
OPT_EXT_ONLY="TV Only"
OPT_INT_ONLY="Laptop Only"

# Show menu
CHOICE=$(echo -e "$OPT_EXTEND_R\n$OPT_EXTEND_L\n$OPT_MIRROR\n$OPT_EXT_ONLY\n$OPT_INT_ONLY" | wofi --dmenu --prompt "Display Mode")

case "$CHOICE" in
    "$OPT_EXTEND_R")
        hyprctl keyword monitor "$INTERNAL, 1920x1200@165, 0x0, 1"
        hyprctl keyword monitor "$EXTERNAL, 1920x1080@60, 1920x0, 1"
        notify-send "Display" "Extended Right"
        ;;
    "$OPT_EXTEND_L")
        hyprctl keyword monitor "$EXTERNAL, 1920x1080@60, 0x0, 1"
        hyprctl keyword monitor "$INTERNAL, 1920x1200@165, 1920x0, 1"
        notify-send "Display" "Extended Left"
        ;;
    "$OPT_MIRROR")
        # Mirroring in Hyprland usually involves setting one to mirror the other
        hyprctl keyword monitor "$INTERNAL, 1920x1200@165, 0x0, 1"
        hyprctl keyword monitor "$EXTERNAL, 1920x1080@60, 0x0, 1, mirror, $INTERNAL"
        notify-send "Display" "Mirrored"
        ;;
    "$OPT_EXT_ONLY")
        hyprctl keyword monitor "$INTERNAL, disable"
        hyprctl keyword monitor "$EXTERNAL, 1920x1080@60, 0x0, 1"
        notify-send "Display" "TV Only"
        ;;
    "$OPT_INT_ONLY")
        hyprctl keyword monitor "$EXTERNAL, disable"
        hyprctl keyword monitor "$INTERNAL, 1920x1200@165, 0x0, 1"
        notify-send "Display" "Laptop Only"
        ;;
esac

# Restart Waybar to fix workspace freezing
pkill waybar
sleep 0.5
waybar &
