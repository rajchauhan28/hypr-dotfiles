#!/bin/bash
# Package update counts by source, as one line of JSON.
# checkupdates syncs a temporary db (network), so the panel runs this on a slow
# timer, never on the reveal path.
# Each source is time-boxed: a stalled mirror held checkupdates (and with it
# the panel's busy spinner) for 14+ minutes. A timed-out source counts as 0.
repo=$( { timeout 90 checkupdates 2>/dev/null; } | wc -l )
aur=$( { timeout 60 yay -Qua 2>/dev/null; } | wc -l )
flat=$( { timeout 60 flatpak remote-ls --updates 2>/dev/null; } | wc -l )
printf '{"repo":%d,"aur":%d,"flatpak":%d,"total":%d}\n' \
    "$repo" "$aur" "$flat" "$((repo + aur + flat))"
