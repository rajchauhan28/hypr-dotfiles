#!/bin/bash

current=$(powerprofilesctl get)

# Determine next profile based on current
if [[ "$current" == "performance" ]]; then
    next="balanced"
elif [[ "$current" == "balanced" ]]; then
    next="power-saver"
else
    next="performance"
fi

# Only set and notify if different
if [[ "$current" != "$next" ]]; then
    powerprofilesctl set "$next"
    notify-send -t 3000 "Power Profile" "Switched to: $next"
fi
