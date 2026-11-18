#!/usr/bin/env bash
# Super+M. Exiting Hyprland closes every app, so it takes an explicit choice in
# the launcher's menu; Escape, a click away or "Cancel" leave the session alone.
set -u
yes="Exit Hyprland (closes every app)"
choice=$(printf '%s\n' "Cancel" "$yes" | "$HOME/.local/bin/qs-dmenu" --dmenu -p "Exit Hyprland?")
[ "$choice" = "$yes" ] || exit 0
exec hyprctl dispatch 'hl.dsp.exit()'
