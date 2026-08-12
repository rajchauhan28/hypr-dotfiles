#!/bin/bash
# Kill only exact quickshell binary instances
killall -9 quickshell 2>/dev/null || true
sleep 0.1
nohup quickshell --allow-duplicate -p "$HOME/.config/quickshell/widgets/$1" >/dev/null 2>&1 &
disown
