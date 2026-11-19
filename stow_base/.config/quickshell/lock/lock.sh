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
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/quickshell-lock.lock"

# Prevent concurrent lock.sh invocations (e.g. idle timer + lid close / double
# Super+L) from racing and killing each other's lock daemon.
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

# Fast, non-mutating liveness check: distinguishes a wedged/missing daemon from
# a healthy daemon that simply takes >2s to compile shaders or load a video
# wallpaper on its first lock.
ipc_ready() {
    timeout 2 qs ipc -n -p "$LOCK_DIR" show 2>/dev/null | grep -q 'target session'
}

ipc_lock() {
    timeout 10 qs ipc -n -p "$LOCK_DIR" call session lock >/dev/null 2>&1
}

lock_pids() {
    qs list -j -p "$LOCK_DIR" 2>/dev/null \
        | python3 -c 'import json,sys; print(" ".join(str(i["pid"]) for i in json.load(sys.stdin)))' 2>/dev/null || true
}

if ipc_ready; then
    if ipc_lock; then
        exit 0
    fi
    # If the lock call timed out, do NOT kill a daemon that actually finished
    # locking Hyprland -- killing a live session-lock client trips Hyprland's
    # red dead-lockscreen (lockdead.png).
    if [ "$(hyprctl locked 2>/dev/null)" = "true" ] && ipc_ready; then
        exit 0
    fi
fi

# Cold path: daemon is missing or genuinely wedged.
# Record PIDs before killing, wait for them to actually exit (SIGKILL if stuck
# in futex_wait, matching reload.sh), then spawn a fresh daemon and wait for
# `ipc show` to advertise `target session` before calling `session lock` once.
# Close fd 9 on the spawned daemon so it never inherits the flock.
pids=$(lock_pids)
if [ -n "$pids" ]; then
    timeout 3 qs kill -p "$LOCK_DIR" >/dev/null 2>&1 || true
    alive=""
    for _ in 1 2 3 4 5 6; do
        alive=""
        for p in $pids; do
            kill -0 "$p" 2>/dev/null && alive="$alive $p"
        done
        [ -z "$alive" ] && break
        sleep 0.5
    done
    for p in $alive; do
        kill -9 "$p" 2>/dev/null || true
    done
    for _ in 1 2 3 4 5; do
        still=""
        for p in $alive; do
            kill -0 "$p" 2>/dev/null && still="$still $p"
        done
        [ -z "$still" ] && break
        sleep 0.1
    done
fi

qs -d -p "$LOCK_DIR" </dev/null >/dev/null 2>&1 9>&-

for _ in $(seq 1 100); do
    if ipc_ready; then
        if ipc_lock; then
            exit 0
        fi
        break
    fi
    sleep 0.1
done

notify-send -u critical "Screen lock FAILED" \
    "The Quickshell lock daemon did not respond. Your session is NOT locked." 2>/dev/null || true
exit 1
