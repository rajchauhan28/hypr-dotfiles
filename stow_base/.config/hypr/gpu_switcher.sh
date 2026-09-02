#!/usr/bin/env bash
# GPU mode and power-profile picker.
#
# The GPU-switching half only applies to an NVIDIA Optimus laptop with
# envycontrol installed. On an AMD or Intel-only machine those entries are
# omitted rather than offered and then failing, and the menu degrades to the
# power tweaks -- which are useful on any laptop.

set -u
# shellcheck source=/dev/null
. "$HOME/.config/hypr/lib/monitors.sh"

has_nvidia() { lspci -nn 2>/dev/null | grep -qi '\[10de:'; }
has_envycontrol() { command -v envycontrol >/dev/null 2>&1; }

OPT_INTEGRATED="Integrated (iGPU Only - Max Battery)"
OPT_HYBRID="Hybrid (Balanced - Default)"
OPT_NVIDIA="NVIDIA (Max Performance - Gaming)"
OPT_OPT_BATTERY="Tweak: Optimize for Battery"
OPT_OPT_GAMING="Tweak: Optimize for Performance"

options=()
if has_nvidia && has_envycontrol; then
    options+=("$OPT_INTEGRATED" "$OPT_HYBRID" "$OPT_NVIDIA")
fi
options+=("$OPT_OPT_BATTERY" "$OPT_OPT_GAMING")

CHOICE=$(printf '%s\n' "${options[@]}" | "$HOME/.local/bin/qs-dmenu" --dmenu -p "GPU Mode & Optimizations")
[ -z "$CHOICE" ] && exit 0

# The panel's own advertised rates, not this laptop's 165/60.
MON="$(mon_internal)"
read -r RATE_HIGH RATE_LOW <<<"$(mon_refresh_rates "$MON")"
RATE_HIGH="${RATE_HIGH:-60}"
RATE_LOW="${RATE_LOW:-60}"

switch_gpu() {
    local mode="$1"
    notify-send "GPU Switch" "Switching to $mode mode. Logout required."
    if sudo envycontrol -s "$mode"; then
        loginctl terminate-user "$USER"
    else
        notify-send "GPU Switch" "envycontrol failed; session left untouched."
    fi
}

case "$CHOICE" in
    "$OPT_INTEGRATED") switch_gpu integrated ;;
    "$OPT_HYBRID")     switch_gpu hybrid ;;
    "$OPT_NVIDIA")     switch_gpu nvidia ;;
    "$OPT_OPT_BATTERY")
        hyprctl keyword monitor "$MON, preferred, auto, $(mon_scale "$MON"), @$RATE_LOW"
        hyprctl keyword decoration:blur:enabled false
        hyprctl keyword decoration:shadow:enabled false
        brightnessctl set 20%
        notify-send "Optimizer" "Battery Eco Mode (${RATE_LOW}Hz, no blur, 20% brightness)"
        ;;
    "$OPT_OPT_GAMING")
        hyprctl keyword monitor "$MON, preferred, auto, $(mon_scale "$MON"), @$RATE_HIGH"
        hyprctl keyword decoration:blur:enabled true
        hyprctl keyword decoration:shadow:enabled true
        brightnessctl set 100%
        notify-send "Optimizer" "Performance Mode (${RATE_HIGH}Hz, 100% brightness)"
        ;;
esac
