#!/bin/bash
# Package update counts by source, as one line of JSON.
# checkupdates syncs a temporary db (network), so the panel runs this on a slow
# timer, never on the reveal path.
repo=$( { checkupdates 2>/dev/null; } | wc -l )
aur=$( { yay -Qua 2>/dev/null; } | wc -l )
flat=$( { flatpak remote-ls --updates 2>/dev/null; } | wc -l )
printf '{"repo":%d,"aur":%d,"flatpak":%d,"total":%d}\n' \
    "$repo" "$aur" "$flat" "$((repo + aur + flat))"
