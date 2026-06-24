#!/bin/bash

# Configuration
OPT_INTEGRATED="Integrated (Intel Only - Max Battery)"
OPT_HYBRID="Hybrid (Balanced - Default)"
OPT_NVIDIA="NVIDIA (Max Performance - Gaming)"
OPT_OPT_BATTERY="Tweak: Optimize for Battery (60Hz + Eco)"
OPT_OPT_GAMING="Tweak: Optimize for Gaming (165Hz + Performance)"

CHOICE=$(echo -e "$OPT_INTEGRATED\n$OPT_HYBRID\n$OPT_NVIDIA\n$OPT_OPT_BATTERY\n$OPT_OPT_GAMING" | wofi --dmenu --prompt "GPU Mode & Optimizations")

case "$CHOICE" in
    "$OPT_INTEGRATED")
        notify-send "GPU Switch" "Switching to Integrated Mode. Logout required."
        sudo envycontrol -s integrated
        loginctl terminate-user $USER
        ;;
    "$OPT_HYBRID")
        notify-send "GPU Switch" "Switching to Hybrid Mode. Logout required."
        sudo envycontrol -s hybrid
        loginctl terminate-user $USER
        ;;
    "$OPT_NVIDIA")
        notify-send "GPU Switch" "Switching to NVIDIA Mode. Logout required."
        sudo envycontrol -s nvidia
        loginctl terminate-user $USER
        ;;
    "$OPT_OPT_BATTERY")
        hyprctl keyword monitor eDP-1, preferred, auto, 1, @60
        hyprctl keyword decoration:blur:enabled false
        hyprctl keyword decoration:shadow:enabled false
        brightnessctl set 20%
        notify-send "Optimizer" "Battery Eco Mode Applied (60Hz, No Blur, 20% Brightness)"
        ;;
    "$OPT_OPT_GAMING")
        hyprctl keyword monitor eDP-1, preferred, auto, 1, @165
        hyprctl keyword decoration:blur:enabled true
        hyprctl keyword decoration:shadow:enabled true
        brightnessctl set 100%
        notify-send "Optimizer" "Gaming Performance Applied (165Hz, 100% Brightness)"
        ;;
esac
