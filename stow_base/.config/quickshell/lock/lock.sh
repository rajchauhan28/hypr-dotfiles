#!/usr/bin/env bash
# Lock the session through the warm `qs -d -c lock` daemon.
#
# The daemon is started at Hyprland launch so the QML engine, Qt modules and
# Theme's helper scripts are already resident; asking it to lock over IPC is
# immediate, where spawning a fresh `qs -c lock` took seconds to show anything.
#
# If the daemon is gone (crash, never started), fall back to the cold path
# rather than leaving the session unlocked.
set -u

if qs -c lock ipc call session lock >/dev/null 2>&1; then
    exit 0
fi

# Cold path. Note the shell starts unlocked, so a bare `qs -c lock` would come
# up showing nothing — the daemon has to be started and *then* told to lock.
qs -d -c lock >/dev/null 2>&1 &

for _ in $(seq 1 100); do
    if qs -c lock ipc call session lock >/dev/null 2>&1; then
        exit 0
    fi
    sleep 0.1
done

exit 1
