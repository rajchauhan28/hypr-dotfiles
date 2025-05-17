#!/bin/bash
if bluetoothctl show | grep -q "Powered: yes"; then
    echo '{"text": "", "tooltip": "Bluetooth On"}'
else
    echo '{"text": "", "tooltip": "Bluetooth Off"}'
fi