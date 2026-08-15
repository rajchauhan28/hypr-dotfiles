#!/usr/bin/env bash

# Hand account switching to SDDM. The current Wayland session remains locked;
# the display manager owns authentication and creation/activation of the other
# user's session.
if command -v qdbus >/dev/null 2>&1; then
    qdbus --system org.freedesktop.DisplayManager \
        /org/freedesktop/DisplayManager/Seat0 \
        org.freedesktop.DisplayManager.Seat.SwitchToGreeter && exit 0
fi

if command -v busctl >/dev/null 2>&1; then
    busctl call org.freedesktop.DisplayManager \
        /org/freedesktop/DisplayManager/Seat0 \
        org.freedesktop.DisplayManager.Seat SwitchToGreeter && exit 0
fi

exit 1
