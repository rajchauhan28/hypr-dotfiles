#!/usr/bin/env bash
# Game Mode: drop every external monitor so the GPU only drives the internal
# panel, and put it back on the second press.
#
# `hyprctl monitors` lists connected outputs only, so a disabled monitor is
# indistinguishable from an unplugged one. The mode is stashed before disabling
# and replayed on restore -- that is what mon_remember/mon_recall are for.

set -u
# shellcheck source=/dev/null
. "$HOME/.config/hypr/lib/monitors.sh"

internal="$(mon_internal)"
if [ -z "$internal" ]; then
    notify-send "Game Mode" "No monitors reported by Hyprland."
    exit 1
fi

mapfile -t externals < <(mon_json | jq -r --arg int "$internal" \
    '.[] | select(.name != $int) | .name')

if [ "${#externals[@]}" -gt 0 ]; then
    for name in "${externals[@]}"; do
        mon_remember "$name"
        hyprctl keyword monitor "$name, disable"
    done
    notify-send "Game Mode" "Enabled: ${#externals[@]} external monitor(s) disabled"
    exit 0
fi

# Nothing external is live. Restore anything we previously disabled; if there
# is no stash either, the user simply has no second monitor plugged in.
restored=0
if [ -d "$MON_STATE_DIR" ]; then
    for state in "$MON_STATE_DIR"/*; do
        [ -e "$state" ] || continue
        name="$(basename "$state")"
        [ "$name" = "$internal" ] && continue
        hyprctl keyword monitor "$name, $(mon_recall "$name")"
        rm -f "$state"
        restored=$((restored + 1))
    done
fi

if [ "$restored" -gt 0 ]; then
    notify-send "Game Mode" "Disabled: $restored monitor(s) restored"
else
    notify-send "Game Mode" "No external monitor to toggle."
fi
