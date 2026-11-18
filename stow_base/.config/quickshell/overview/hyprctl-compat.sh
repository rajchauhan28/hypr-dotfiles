#!/bin/bash
CMD=$1
shift
ARGS="$*"

if [ "$CMD" = "movetoworkspacesilent" ]; then
    WS=$(echo "$ARGS" | cut -d',' -f1)
    ADDR=$(echo "$ARGS" | cut -d',' -f2)
    /usr/bin/hyprctl eval "hl.dispatch(hl.dsp.window.move({ workspace = \"$WS\", window = \"$ADDR\", silent = true }))"
elif [ "$CMD" = "workspace" ]; then
    /usr/bin/hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = \"$ARGS\" }))"
elif [ "$CMD" = "focuswindow" ]; then
    /usr/bin/hyprctl eval "hl.dispatch(hl.dsp.focus({ window = \"$ARGS\" }))"
elif [ "$CMD" = "closewindow" ]; then
    /usr/bin/hyprctl eval "hl.dispatch(hl.dsp.window.close({ window = \"$ARGS\" }))"
elif [ "$CMD" = "togglespecialworkspace" ]; then
    /usr/bin/hyprctl eval "hl.dispatch(hl.dsp.workspace.toggle_special(\"$ARGS\"))"
else
    /usr/bin/hyprctl dispatch "$CMD" "$ARGS"
fi
