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

# Run one monitor change, collecting Hyprland's error instead of dropping it.
errors=""
try() { local err; err="$("$@" 2>&1)" || errors+="${err:-$1 failed}"$'\n'; }
report() {
    if [ -n "$errors" ]; then
        notify-send -u critical "Display" "$1 failed: $errors"
    else
        notify-send "Display" "$1"
    fi
}

case "$CHOICE" in
    "$OPT_EXTEND_R")
        try mon_apply "$INTERNAL" "$int_mode" 0x0 "$int_scale"
        try mon_apply "$EXTERNAL" "$ext_mode" "${int_logical_w}x0" "$ext_scale"
        report "Extended Right"
        ;;
    "$OPT_EXTEND_L")
        try mon_apply "$EXTERNAL" "$ext_mode" 0x0 "$ext_scale"
        try mon_apply "$INTERNAL" "$int_mode" "${ext_logical_w}x0" "$int_scale"
        report "Extended Left"
        ;;
    "$OPT_MIRROR")
        try mon_apply "$INTERNAL" "$int_mode" 0x0 "$int_scale"
        try mon_apply "$EXTERNAL" "$ext_mode" 0x0 "$ext_scale" "$INTERNAL"
        report "Mirrored"
        ;;
    "$OPT_EXT_ONLY")
        mon_remember "$INTERNAL"
        try mon_apply "$EXTERNAL" "$ext_mode" 0x0 "$ext_scale"
        try mon_disable "$INTERNAL"
        report "External Only"
        ;;
    "$OPT_INT_ONLY")
        mon_remember "$EXTERNAL"
        try mon_apply "$INTERNAL" "$int_mode" 0x0 "$int_scale"
        try mon_disable "$EXTERNAL"
        report "Laptop Only"
        ;;
esac
