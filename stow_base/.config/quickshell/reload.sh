#!/usr/bin/env bash

set -u

configs=(topbar leftbar dock sidepanel widgets/desktop_clock lock notifications)

# Ask Quickshell to stop the exact configurations instead of matching process
# command lines. This avoids killing unrelated shells and works regardless of
# whether the executable appears as "qs" or "quickshell" in the process list.
for config in "${configs[@]}"; do
    qs kill --any-display -c "$config" >/dev/null 2>&1 || true
done

for config in "${configs[@]}"; do
    qs -d -c "$config"
done
