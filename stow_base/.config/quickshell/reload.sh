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
#
# An instance can wedge on its way out (seen right after a hot reload): it
# logs "Exiting due to IPC request" and then sits in futex_wait forever, and
# the `qs -d` below refuses to start while it is alive -- leaving no bars at
# all. So note the bars' PIDs first (`qs list` without -a skips the lock), give
# them 3 s to exit, and SIGKILL whatever is still there.
pids=$(qs list -j 2>/dev/null | python3 -c 'import json,sys; print(" ".join(str(i["pid"]) for i in json.load(sys.stdin)))' 2>/dev/null)
qs kill --any-display >/dev/null 2>&1 || true
alive=""
for _ in 1 2 3 4 5 6; do
    alive=""
    for p in $pids; do kill -0 "$p" 2>/dev/null && alive="$alive $p"; done
    [ -z "$alive" ] && break
    sleep 0.5
done
for p in $alive; do kill -9 "$p" 2>/dev/null; done
qs -d >/dev/null 2>&1

if [ "$with_lock" = 1 ]; then
    qs kill --any-display -p "$HOME/.config/quickshell/lock" >/dev/null 2>&1 || true
    sleep 0.5
    qs -d -p "$HOME/.config/quickshell/lock" >/dev/null 2>&1
fi
