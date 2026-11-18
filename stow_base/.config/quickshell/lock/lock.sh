#!/usr/bin/env bash
# Lock the session through the warm lock daemon.
#
# NOTE THE `-p`, NOT `-c`. Since the panels were consolidated into
# ~/.config/quickshell/shell.qml, quickshell registers that file as the
# 'default' config and -- in its own words -- "no subdirectories will be
# considered". Every `qs -c <name>` in this repo silently stopped resolving,
# which meant this script's IPC call AND its cold fallback both failed and
# Super+L stopped locking the session at all. Select by path instead.
#
# The daemon is started at Hyprland launch so the QML engine, Qt modules and
# Theme's helper scripts are already resident; asking it to lock over IPC is
# immediate, where spawning a fresh instance took seconds to show anything.
#
# If the daemon is gone (crash, never started) or wedged, fall back to the
# cold path rather than leaving the session unlocked -- and if even that
# fails, say so loudly instead of exiting 1 into the void.
set -u

LOCK_DIR="$HOME/.config/quickshell/lock"

# Time-boxed: a daemon wedged in futex_wait (see reload.sh) used to hang this
# call forever, so the cold path below was never reached.
ipc_lock() {
    timeout 2 qs -p "$LOCK_DIR" ipc call session lock >/dev/null 2>&1
}

if ipc_lock; then
    exit 0
fi

# Cold path. Clear out a wedged instance first, or the fresh one is just a
# second unresponsive process. Killing it is safe even mid-lock: the session
# lock protocol keeps the compositor locked when the client dies, and
# misc.allow_session_lock_restore (hyprland.lua) lets the new one take over.
# The shell starts unlocked, so it has to be started and *then* told to lock.
timeout 3 qs kill -p "$LOCK_DIR" >/dev/null 2>&1 || true
qs -d -p "$LOCK_DIR" >/dev/null 2>&1 &

for _ in $(seq 1 100); do
    if ipc_lock; then
        exit 0
    fi
    sleep 0.1
done

notify-send -u critical "Screen lock FAILED" \
    "The Quickshell lock daemon did not respond. Your session is NOT locked." 2>/dev/null || true
exit 1
