#!/bin/bash
# Check if the monitor is currently disabled
MONITOR_STATUS=$(hyprctl monitors | grep "HDMI-A-1")

if [ -n "$MONITOR_STATUS" ]; then
    # Monitor is active, so we disable it (Game Mode ON)
    hyprctl keyword monitor "HDMI-A-1, disable"
    notify-send "Game Mode" "Enabled: Monitor disabled for performance"
else
    # Monitor is disabled (not found in monitors list), so we enable it (Game Mode OFF)
    hyprctl keyword monitor "HDMI-A-1, 1920x1080@60, auto, 1"
    notify-send "Game Mode" "Disabled: Monitor restored"
fi