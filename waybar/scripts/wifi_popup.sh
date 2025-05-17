#!/bin/bash
refresh() {
    nmcli -t -f active,ssid dev wifi | awk -F: '{print ($1 == "yes" ? " [Connected] " : "   ") $2}' | sed '/^ *$/d'
}

while true; do
    menu="$(refresh; echo "🔄 Refresh"; echo "Close")"
    selected=$(echo "$menu" | rofi -dmenu -p "WiFi Networks")

    if [[ -z "$selected" || "$selected" == "Close" ]]; then
        exit 0
    elif [[ "$selected" == "🔄 Refresh" ]]; then
        continue
    else
        ssid=$(echo "$selected" | sed -E 's/^.*$$Connected$$ //; s/^ *//')
        nmcli device wifi connect "$ssid"
        exit 0
    fi
done