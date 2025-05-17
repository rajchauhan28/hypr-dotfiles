#!/bin/bash
if nmcli radio wifi | grep -q enabled; then
    ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
    if [[ -n "$ssid" ]]; then
        echo '{"text": "", "tooltip": "Connected: '"$ssid"'"}'
    else
        echo '{"text": "睊", "tooltip": "WiFi On, Not Connected"}'
    fi
else
    echo '{"text": "", "tooltip": "WiFi Off"}'
fi