#!/usr/bin/env bash

# Count the number of connected monitors
monitor_count=$(hyprctl monitors -j | jq '. | length')

# If more than 1 monitor, output the icon and tooltip info
if [ "$monitor_count" -gt 1 ]; then
    echo '{"text": "󰍹", "tooltip": "Switch Display Mode", "class": "visible"}'
else
    echo '{"text": "", "tooltip": "", "class": "hidden"}'
fi
