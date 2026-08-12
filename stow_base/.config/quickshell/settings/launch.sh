#!/bin/bash
# Toggle the shell settings from a single keybind:
#
#   not running          -> open it
#   running, focused     -> close it
#   running, not focused -> raise and focus it
#
# The middle case is what makes Super+comma a real toggle; the last one means
# pressing the bind while working in another window brings settings forward
# instead of closing something you cannot see.

if ! qs -c settings ipc call settings open >/dev/null 2>&1; then
    exec qs -c settings
fi

active=$(hyprctl -j activewindow 2>/dev/null | python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get("title") or "")
except Exception:
    print("")')

if [ "$active" = "Shell Settings" ]; then
    qs -c settings ipc call settings quit >/dev/null 2>&1
else
    # NOT `hyprctl dispatch focuswindow ...`: this Hyprland is configured in
    # Lua, so dispatch arguments are parsed as Lua and a bare `title:...` is a
    # syntax error. `eval` takes the real call.
    hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "title:Shell Settings" }))' >/dev/null 2>&1
fi
