#!/bin/bash

# A more advanced Waybar script for KDE Connect, prioritizing notifications and media.

# Exit if KDE Connect is not running
if ! pgrep -x "kdeconnectd" > /dev/null;
then
    echo '{"text": "", "tooltip": "KDE Connect not running", "class": "disconnected"}'
    exit 0
fi

# --- Find all available (paired and reachable) devices ---
CONNECTED_DEVICES_INFO=$(kdeconnect-cli -a --id-name-only)

# --- Exit if no devices are connected ---
if [ -z "$CONNECTED_DEVICES_INFO" ]; then
    echo '{"text": "", "tooltip": "No devices connected", "class": "disconnected"}'
    exit 0
fi

# --- Aggregate data from all connected devices ---
TOTAL_NOTIF_COUNT=0
ALL_DEVICES_TOOLTIP=""
MEDIA_INFO_TEXT=""
MEDIA_CLASS=""
BATTERY_INFO_TEXT=""

while read -r line; do
    DEVICE_ID=$(echo "$line" | awk '{print $1}')
    DEVICE_NAME=$(echo "$line" | cut -d' ' -f2-)
    NOTIF_COUNT=$(kdeconnect-cli -d "$DEVICE_ID" --list-notifications | grep -c .)

    ALL_DEVICES_TOOLTIP+="\nDevice: $DEVICE_NAME"
    
    if [ "$NOTIF_COUNT" -gt 0 ]; then
        TOTAL_NOTIF_COUNT=$((TOTAL_NOTIF_COUNT + NOTIF_COUNT))
        ALL_DEVICES_TOOLTIP+="\nNotifications: $NOTIF_COUNT"
    fi

    # --- Battery Info ---
    BATTERY_CHARGE=$(qdbus org.kde.kdeconnect /modules/kdeconnect/devices/$DEVICE_ID/battery org.kde.kdeconnect.device.battery.charge 2>/dev/null)
    if [ -n "$BATTERY_CHARGE" ]; then
        BATTERY_CHARGING=$(qdbus org.kde.kdeconnect /modules/kdeconnect/devices/$DEVICE_ID/battery org.kde.kdeconnect.device.battery.isCharging 2>/dev/null)
        BATTERY_INFO_TEXT="$BATTERY_CHARGE%"
        ALL_DEVICES_TOOLTIP+="\nBattery: $BATTERY_CHARGE%"
        if [ "$BATTERY_CHARGING" = "true" ]; then
            BATTERY_INFO_TEXT+=" "
            ALL_DEVICES_TOOLTIP+=" (Charging)"
        fi
    fi

    # --- Media Info (prioritize the first playing device) ---
    PLAYER_STATUS=$(qdbus org.kde.kdeconnect /modules/kdeconnect/devices/"$DEVICE_ID"/mpris org.mpris.MediaPlayer2.Player.PlaybackStatus 2>/dev/null)
    if [[ -z "$MEDIA_INFO_TEXT" && "$PLAYER_STATUS" == "Playing" ]]; then
        METADATA=$(qdbus org.kde.kdeconnect /modules/kdeconnect/devices/"$DEVICE_ID"/mpris org.mpris.MediaPlayer2.Player.Metadata 2>/dev/null)
        TRACK_ARTIST=$(echo "$METADATA" | grep 'xesam:artist:' | cut -d ' ' -f 2-)
        TRACK_TITLE=$(echo "$METADATA" | grep 'xesam:title:' | cut -d ' ' -f 2-)
        
        if [ -n "$TRACK_ARTIST" ] && [ -n "$TRACK_TITLE" ]; then
            TRACK_INFO="$TRACK_ARTIST - $TRACK_TITLE"
            # Smart truncation
            TRUNCATED_TRACK_INFO=$(echo "$TRACK_INFO" | awk '{if(length > 30) print substr($0, 1, 27)"..."; else print $0}')
            MEDIA_INFO_TEXT="懶 $TRUNCATED_TRACK_INFO"
            MEDIA_CLASS="media-playing"
            ALL_DEVICES_TOOLTIP+="\nMedia: Playing - $TRACK_INFO"
        fi
    elif [ "$PLAYER_STATUS" == "Paused" ]; then
         ALL_DEVICES_TOOLTIP+="\nMedia: Paused"
    fi
done <<< "$CONNECTED_DEVICES_INFO"


# --- Logic to decide what to display ---
INFO_TEXT=""
INFO_CLASS="connected"
TOOLTIP="KDE Connect"

if [ -n "$BATTERY_INFO_TEXT" ]; then
    INFO_TEXT+="$BATTERY_INFO_TEXT"
fi

if [ "$TOTAL_NOTIF_COUNT" -gt 0 ]; then
    if [ -n "$INFO_TEXT" ]; then
        INFO_TEXT+=" | "
    fi
    INFO_TEXT+=" $TOTAL_NOTIF_COUNT"
    INFO_CLASS="notifications"
fi

if [ "$TOTAL_NOTIF_COUNT" -eq 0 ] && [ -n "$MEDIA_INFO_TEXT" ]; then
    if [ -n "$INFO_TEXT" ]; then
        INFO_TEXT+=" | "
    fi
    INFO_TEXT+="$MEDIA_INFO_TEXT"
    INFO_CLASS="$MEDIA_CLASS"
fi

if [ -z "$INFO_TEXT" ]; then
    INFO_TEXT=""
fi

# --- Final JSON Output using jq ---
jq -n \
  --arg text "$INFO_TEXT" \
  --arg tooltip "$(echo -e ${TOOLTIP}${ALL_DEVICES_TOOLTIP})" \
  --arg class "$INFO_CLASS" \
  '{"text": $text, "tooltip": $tooltip, "class": $class}'