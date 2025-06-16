#!/bin/bash

WIN_ID=$(hyprctl clients -j | jq -r '.[] | select(.initialClass=="bluetuith-popup") | .address')

if [[ -n "$WIN_ID" ]]; then
    hyprctl dispatch closewindow address:$WIN_ID
else
    kitty --class bluetuith-popup -e bluetuith &
fi
