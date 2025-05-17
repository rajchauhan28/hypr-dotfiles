#!/bin/bash
refresh() {
    bluetoothctl devices | awk '{print $2 "  " substr($0, index($0,$3))}'
}

while true; do
    menu="$(refresh; echo "🔄 Refresh"; echo "Close")" 
    selected=$(echo "$menu" | rofi -dmenu -p "Bluetooth devices")

    if [[ -z "$selected" || "$selected" == "Close" ]]; then
        exit 0
    elif [[ "$selected" == "🔄 Refresh" ]]; then
        continue
    else
        mac=$(echo "$selected" | awk '{print $1}')
        bluetoothctl connect "$mac"
        exit 0
    fi
done