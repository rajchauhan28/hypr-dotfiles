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
#
# `-p`, not `-c`: ~/.config/quickshell/shell.qml is registered as the 'default'
# config, and quickshell then considers no subdirectories at all, so `-c
# settings` resolves to nothing. Same trap that stopped Super+L locking.

if ! qs -p "$HOME/.config/quickshell/settings" ipc call settings open >/dev/null 2>&1; then
    exec qs -p "$HOME/.config/quickshell/settings"
fi

active=$(hyprctl -j activewindow 2>/dev/null | python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get("title") or "")
except Exception:
    print("")')

if [ "$active" = "Shell Settings" ]; then
    qs -p "$HOME/.config/quickshell/settings" ipc call settings quit >/dev/null 2>&1
else
    # NOT `hyprctl dispatch focuswindow ...`: this Hyprland is configured in
    # Lua, so dispatch arguments are parsed as Lua and a bare `title:...` is a
    # syntax error. `eval` takes the real call.
    hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "title:Shell Settings" }))' >/dev/null 2>&1
fi
