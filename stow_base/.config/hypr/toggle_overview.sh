#!/bin/bash
if pgrep -f "quickshell.*overview" >/dev/null; then
    pkill -f "quickshell.*overview"
else
    qs -p /home/reign/.config/quickshell/overview
fi
