#!/usr/bin/env bash
# Reload the consolidated Quickshell bars.
#
# topbar + leftbar + sidepanel + dock + desktop_clock + notifications are one
# process (~/.config/quickshell/shell.qml, the default config), so a reload is a
# single kill/start rather than six.
#
# The lockscreen is deliberately NOT reloaded here. It is its own daemon
# (its own `qs -d -p .../lock`) so reloading the bars can never drop a lock.
# Pass --with-lock to restart it too, and only ever while unlocked.

set -u

with_lock=0
[ "${1:-}" = "--with-lock" ] && with_lock=1

# Kill by config path, not `pkill -f` — a `pkill -f "qs ..."` pattern also
# matches the invoking shell's own command line and kills the caller.
qs kill --any-display >/dev/null 2>&1 || true
sleep 0.5
qs -d >/dev/null 2>&1

if [ "$with_lock" = 1 ]; then
    qs kill --any-display -p "$HOME/.config/quickshell/lock" >/dev/null 2>&1 || true
    sleep 0.5
    qs -d -p "$HOME/.config/quickshell/lock" >/dev/null 2>&1
fi
