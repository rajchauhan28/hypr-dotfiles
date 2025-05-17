#!/bin/bash
status=$(playerctl status 2>/dev/null)
if [[ $status == "Playing" ]]; then
    play_pause_icon=""  # pause icon
else
    play_pause_icon=""  # play icon
fi

echo '{"text": "  '"$play_pause_icon"'  ", "tooltip": "Previous | Play/Pause | Next"}'