#!/bin/bash
# Launch/Toggle script for Quickshell Anurati Pywal Desktop Clock
if quickshell list --all | grep -q "desktop_clock"; then
    quickshell kill -p "$HOME/.config/quickshell/widgets/desktop_clock" 2>/dev/null || pkill -f "quickshell.*desktop_clock"
else
    quickshell -d -p "$HOME/.config/quickshell/widgets/desktop_clock"
fi
