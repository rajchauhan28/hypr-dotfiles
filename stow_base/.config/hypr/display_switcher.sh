#!/usr/bin/env bash
# Multi-monitor layout picker. Detects which outputs are actually connected
# instead of assuming an eDP-1 + HDMI-A-1 pair, and reuses each monitor's own
# current mode rather than forcing 1920x1200@165 / 1920x1080@60.

set -u
# shellcheck source=/dev/null
. "$HOME/.config/hypr/lib/monitors.sh"

INTERNAL="$(mon_internal)"
EXTERNAL="$(mon_external)"

if [ -z "$INTERNAL" ]; then
    notify-send "Display" "No monitors reported by Hyprland."
    exit 1
fi

if [ -z "$EXTERNAL" ]; then
    # Offer the restore path anyway: an external monitor that was disabled by
    # a previous run is not "connected" as far as hyprctl is concerned.
    for state in "$MON_STATE_DIR"/*; do
        [ -e "$state" ] || continue
        candidate="$(basename "$state")"
        [ "$candidate" != "$INTERNAL" ] && EXTERNAL="$candidate" && break
    done
fi

if [ -z "$EXTERNAL" ]; then
    notify-send "Display" "Only $INTERNAL is connected."
    exit 0
fi

# "preferred" lets Hyprland pick the best mode for a monitor we have never
# seen active, which is the right default for a freshly plugged-in display.
int_mode="$(mon_mode "$INTERNAL")"; int_mode="${int_mode:-preferred}"
ext_mode="$(mon_mode "$EXTERNAL")"; ext_mode="${ext_mode:-preferred}"
int_scale="$(mon_scale "$INTERNAL")"
ext_scale="$(mon_scale "$EXTERNAL")"

# Placing the second monitor needs the first one's logical width, which is the
# pixel width divided by its scale.
int_logical_w="$(mon_json | jq -r --arg n "$INTERNAL" \
    'map(select(.name == $n)) | first | ((.width / (.scale // 1)) | floor) // 1920')"
ext_logical_w="$(mon_json | jq -r --arg n "$EXTERNAL" \
    'map(select(.name == $n)) | first | ((.width / (.scale // 1)) | floor) // 1920')"

OPT_EXTEND_R="Extend (Right)"
OPT_EXTEND_L="Extend (Left)"
OPT_MIRROR="Mirror"
OPT_EXT_ONLY="External Only ($EXTERNAL)"
OPT_INT_ONLY="Laptop Only ($INTERNAL)"

CHOICE=$(printf '%s\n' "$OPT_EXTEND_R" "$OPT_EXTEND_L" "$OPT_MIRROR" \
    "$OPT_EXT_ONLY" "$OPT_INT_ONLY" | "$HOME/.local/bin/qs-dmenu" --dmenu -p "Display Mode")

case "$CHOICE" in
    "$OPT_EXTEND_R")
        hyprctl keyword monitor "$INTERNAL, $int_mode, 0x0, $int_scale"
        hyprctl keyword monitor "$EXTERNAL, $ext_mode, ${int_logical_w}x0, $ext_scale"
        notify-send "Display" "Extended Right"
        ;;
    "$OPT_EXTEND_L")
        hyprctl keyword monitor "$EXTERNAL, $ext_mode, 0x0, $ext_scale"
        hyprctl keyword monitor "$INTERNAL, $int_mode, ${ext_logical_w}x0, $int_scale"
        notify-send "Display" "Extended Left"
        ;;
    "$OPT_MIRROR")
        hyprctl keyword monitor "$INTERNAL, $int_mode, 0x0, $int_scale"
        hyprctl keyword monitor "$EXTERNAL, $ext_mode, 0x0, $ext_scale, mirror, $INTERNAL"
        notify-send "Display" "Mirrored"
        ;;
    "$OPT_EXT_ONLY")
        mon_remember "$INTERNAL"
        hyprctl keyword monitor "$EXTERNAL, $ext_mode, 0x0, $ext_scale"
        hyprctl keyword monitor "$INTERNAL, disable"
        notify-send "Display" "External Only"
        ;;
    "$OPT_INT_ONLY")
        mon_remember "$EXTERNAL"
        hyprctl keyword monitor "$INTERNAL, $int_mode, 0x0, $int_scale"
        hyprctl keyword monitor "$EXTERNAL, disable"
        notify-send "Display" "Laptop Only"
        ;;
esac
