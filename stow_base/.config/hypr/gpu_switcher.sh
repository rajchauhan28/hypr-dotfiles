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

# envycontrol's integrated mode does not merely blacklist the driver -- it
# writes a udev rule that does ATTR{remove}="1" on every 10de device at boot,
# so the card leaves the PCI bus entirely and lspci goes blind. Gating the
# menu on lspci alone therefore hides the Hybrid/NVIDIA entries at exactly the
# moment they are the only way back. Those two files are only ever generated
# on a machine that has a dGPU, so they stand in as proof of one.
has_nvidia() {
    lspci -nn 2>/dev/null | grep -qi '\[10de:' && return 0
    # envycontrol records the dGPU's bus address when it first detects one, and
    # that survives every mode and every reboot. It is the only signal that
    # holds in the gap between switching to hybrid -- which deletes both files
    # below -- and the reboot that actually puts the card back on the bus.
    envycontrol --cache-query 2>/dev/null | grep -q nvidia_gpu_pci_bus && return 0
    [ -e /etc/udev/rules.d/50-remove-nvidia.rules ] && return 0
    [ -e /etc/modprobe.d/blacklist-nvidia.conf ] && return 0
    return 1
}
has_envycontrol() { command -v envycontrol >/dev/null 2>&1; }
current_mode() { envycontrol --query 2>/dev/null | tr -d '[:space:]'; }

# nvidia-powerd (Dynamic Boost) keeps /dev/nvidia0 open for as long as it runs,
# which stops the dGPU from ever runtime-suspending -- ~2 W and the matching
# chassis heat, even at 0% utilisation. It only buys anything while a game is
# actually on the dGPU, so it follows the profile instead of running always.
# pkexec, not sudo: this script is launched from a dmenu with no controlling
# terminal, so sudo has nothing to prompt on.
powerd() {
    systemctl cat nvidia-powerd >/dev/null 2>&1 || return 0
    pkexec systemctl "$@" nvidia-powerd >/dev/null 2>&1
}

OPT_INTEGRATED="Integrated (iGPU Only - Max Battery)"
OPT_HYBRID="Hybrid (Balanced - Default)"
OPT_NVIDIA="NVIDIA (Max Performance - Gaming)"
OPT_OPT_BATTERY="Tweak: Optimize for Battery"
OPT_OPT_GAMING="Tweak: Optimize for Performance"

# Tag whichever mode is live, so the menu answers "what am I on now?" without
# a trip to a terminal. The tag is display-only and is stripped back off below.
ACTIVE_TAG="  (active)"
MODE="$(current_mode)"
tag() { # $1 = option label, $2 = the envycontrol mode it selects
    if [ "$MODE" = "$2" ]; then printf '%s%s' "$1" "$ACTIVE_TAG"; else printf '%s' "$1"; fi
}

options=()
if has_nvidia && has_envycontrol; then
    options+=("$(tag "$OPT_INTEGRATED" integrated)")
    options+=("$(tag "$OPT_HYBRID" hybrid)")
    options+=("$(tag "$OPT_NVIDIA" nvidia)")
fi
options+=("$OPT_OPT_BATTERY" "$OPT_OPT_GAMING")

CHOICE=$(printf '%s\n' "${options[@]}" | "$HOME/.local/bin/qs-dmenu" --dmenu -p "GPU Mode & Optimizations")
[ -z "$CHOICE" ] && exit 0
CHOICE="${CHOICE%"$ACTIVE_TAG"}"

# The panel's own advertised rates, not this laptop's 165/60.
MON="$(mon_internal)"
read -r RATE_HIGH RATE_LOW <<<"$(mon_refresh_rates "$MON")"
RATE_HIGH="${RATE_HIGH:-60}"
RATE_LOW="${RATE_LOW:-60}"

switch_gpu() {
    local mode="$1" bin rc
    # pkexec rather than sudo, for the reason given above powerd(). Resolve the
    # path first: pkexec sanitises the environment, so PATH may not survive.
    bin="$(command -v envycontrol)" || {
        notify-send "GPU Switch" "envycontrol not found."
        return 1
    }

    notify-send "GPU Switch" "Switching to $mode mode..."
    pkexec "$bin" -s "$mode"
    rc=$?

    # A reboot, not a logout. Leaving integrated mode means dropping the udev
    # rule that removes the card from the PCI bus and rebuilding the initramfs
    # without the blacklist; neither is re-read until boot, so a terminated
    # session comes back looking exactly as broken as before. Say so, and let
    # the reboot happen on the user's terms rather than yanking the session.
    case "$rc" in
        0)   notify-send -u critical "GPU Switch" \
                 "Mode set to $mode. REBOOT to apply -- a logout is not enough." ;;
        126) notify-send "GPU Switch" "Cancelled at the authentication prompt." ;;
        127) notify-send "GPU Switch" "Not authorised to run envycontrol." ;;
        *)   notify-send "GPU Switch" \
                 "envycontrol failed (exit $rc); session left untouched." ;;
    esac
}

case "$CHOICE" in
    "$OPT_INTEGRATED") switch_gpu integrated ;;
    "$OPT_HYBRID")     switch_gpu hybrid ;;
    "$OPT_NVIDIA")     powerd enable --now; switch_gpu nvidia ;;
    "$OPT_OPT_BATTERY")
        hyprctl keyword monitor "$MON, preferred, auto, $(mon_scale "$MON"), @$RATE_LOW"
        hyprctl keyword decoration:blur:enabled false
        hyprctl keyword decoration:shadow:enabled false
        brightnessctl set 20%
        # disable --now, not stop. The NVIDIA mode entry enables nvidia-powerd
        # persistently, so a bare `stop` only quietened it until the next boot
        # and the dGPU went back to being pinned awake with no sign of why.
        powerd disable --now
        notify-send "Optimizer" "Battery Eco Mode (${RATE_LOW}Hz, no blur, 20% brightness, Dynamic Boost off for good)"
        ;;
    "$OPT_OPT_GAMING")
        hyprctl keyword monitor "$MON, preferred, auto, $(mon_scale "$MON"), @$RATE_HIGH"
        hyprctl keyword decoration:blur:enabled true
        hyprctl keyword decoration:shadow:enabled true
        brightnessctl set 100%
        powerd start
        notify-send "Optimizer" "Performance Mode (${RATE_HIGH}Hz, 100% brightness, Dynamic Boost on)"
        ;;
esac
