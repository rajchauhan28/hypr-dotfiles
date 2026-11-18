#!/usr/bin/env bash
# Run by glass.lua when the glass theme is on but hyprglass.so is missing
# ("missing") or was built for a different Hyprland ("stale"), so it was not
# loaded. Says so once per login -- glass.lua runs on every config reload --
# and a click on the notification rebuilds the plugin in a terminal, then
# reloads Hyprland so glass.lua loads the new build.
set -u
flag="${XDG_RUNTIME_DIR:-/tmp}/hyprglass-stale-notified"
[ -e "$flag" ] && exit 0
: >"$flag"

if [ "${1:-stale}" = missing ]; then
    body="The glass theme needs the hyprglass plugin, which is not built yet."
else
    body="hyprglass was built for a different Hyprland version, so it was not loaded."
fi
body="$body Glass shows as plain translucent dark until it is rebuilt. Click to rebuild."

# "default" is the whole-notification click (see hypr/screenshot.sh).
action=$(notify-send -a "Liquid glass" -A default=Rebuild "Glass plugin needs a rebuild" "$body")
[ "$action" = default ] || exit 0

# shellcheck disable=SC2016 # expanded by the inner bash
exec ghostty -e bash -c '
"$HOME/.config/hypr/build-hyprglass.sh" && hyprctl reload >/dev/null && echo && echo "Done: glass is loaded."
echo; read -rp "Press Enter to close."'
