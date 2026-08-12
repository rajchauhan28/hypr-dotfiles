#!/bin/bash
CMD=$1
shift
ARGS="$*"

echo "[$(date)] CMD: '$CMD', ARGS: '$ARGS'" >> /tmp/hyprctl-compat.log

if [ "$CMD" = "movetoworkspacesilent" ]; then
    WS=$(echo "$ARGS" | cut -d',' -f1)
    ADDR=$(echo "$ARGS" | cut -d',' -f2)
    /usr/bin/hyprctl eval "hl.dispatch(hl.dsp.window.move({ workspace = \"$WS\", window = \"$ADDR\", silent = true }))" >> /tmp/hyprctl-compat.log 2>&1
elif [ "$CMD" = "workspace" ]; then
    /usr/bin/hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = \"$ARGS\" }))" >> /tmp/hyprctl-compat.log 2>&1
elif [ "$CMD" = "focuswindow" ]; then
    /usr/bin/hyprctl eval "hl.dispatch(hl.dsp.focus({ window = \"$ARGS\" }))" >> /tmp/hyprctl-compat.log 2>&1
elif [ "$CMD" = "closewindow" ]; then
    /usr/bin/hyprctl eval "hl.dispatch(hl.dsp.window.close({ window = \"$ARGS\" }))" >> /tmp/hyprctl-compat.log 2>&1
elif [ "$CMD" = "togglespecialworkspace" ]; then
    /usr/bin/hyprctl eval "hl.dispatch(hl.dsp.workspace.toggle_special(\"$ARGS\"))" >> /tmp/hyprctl-compat.log 2>&1
else
    /usr/bin/hyprctl dispatch "$CMD" "$ARGS" >> /tmp/hyprctl-compat.log 2>&1
fi
