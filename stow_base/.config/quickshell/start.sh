#!/usr/bin/env bash
# Start the bars at login, and start them again if the shell dies on the way
# up. Login is when it has crashed: Qt aborts when an icon is loaded off the
# GUI thread, a race that busy logins lose (coredumps 2026-10-10 10:15 and
# 21:42). The async icon images are gone, so this is a safety net.
for _ in 1 2 3; do
    qs -d >/dev/null 2>&1
    sleep 5
    qs list -j 2>/dev/null | grep -q '"pid"' && exit 0
done
exit 1
