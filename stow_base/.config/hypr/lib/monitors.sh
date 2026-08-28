#!/usr/bin/env bash
# Shared monitor detection. Sourced (never executed) by gamemode.sh,
# display_switcher.sh and gpu_switcher.sh so none of them has to hardcode
# "eDP-1", "HDMI-A-1", or this laptop's 1920x1200@165 panel.
#
# Everything is read live from `hyprctl monitors -j`, which lists only
# CONNECTED outputs. A monitor that was disabled with `monitor = <name>,disable`
# disappears from that list, so callers that need to re-enable one must
# remember its mode -- hence mon_remember/mon_recall below.

# Directory for remembered modes. XDG_RUNTIME_DIR is per-session and cleared on
# logout, which is exactly the lifetime a "temporarily disabled monitor" has.
MON_STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hypr-monitors"

# mon_json -- raw `hyprctl monitors -j`, or an empty array when Hyprland or jq
# is unavailable so every helper below degrades to "no monitors" instead of
# erroring out mid-script.
mon_json() {
    command -v hyprctl >/dev/null 2>&1 || { echo '[]'; return; }
    command -v jq >/dev/null 2>&1 || { echo '[]'; return; }
    hyprctl monitors -j 2>/dev/null || echo '[]'
}

# mon_internal -- the built-in laptop panel, matched by connector type rather
# than by name, so eDP-1/eDP-2/LVDS-1/DSI-1 all resolve. Falls back to the
# first connected output on a desktop, which has no internal panel at all.
mon_internal() {
    mon_json | jq -r '
        (map(select(.name | test("^(eDP|LVDS|DSI)"; "i"))) | first | .name)
        // (first | .name) // empty'
}

# mon_external -- the first connected output that is not the internal panel.
# Empty when nothing is plugged in; callers must handle that.
mon_external() {
    local internal; internal="$(mon_internal)"
    mon_json | jq -r --arg int "$internal" '
        map(select(.name != $int)) | first | .name // empty'
}

# mon_mode <name> -- the monitor's current mode as "WIDTHxHEIGHT@REFRESH",
# ready to paste into a `hyprctl keyword monitor` line.
mon_mode() {
    mon_json | jq -r --arg n "$1" '
        map(select(.name == $n)) | first
        | if . == null then empty
          else "\(.width)x\(.height)@\(.refreshRate | floor)" end'
}

# mon_scale <name> -- the monitor's current scale factor, defaulting to 1.
mon_scale() {
    local s; s="$(mon_json | jq -r --arg n "$1" \
        'map(select(.name == $n)) | first | .scale // 1')"
    [ -n "$s" ] && [ "$s" != "null" ] && echo "$s" || echo 1
}

# mon_refresh_rates <name> -- the highest and lowest refresh rates the panel
# advertises at its CURRENT resolution, printed as "HIGH LOW". Used by the
# battery/gaming refresh toggles that used to assume 165 and 60.
mon_refresh_rates() {
    local name="$1"
    mon_json | jq -r --arg n "$name" '
        map(select(.name == $n)) | first as $m
        | if $m == null then empty else
            ($m.availableModes // [])
            | map(capture("^(?<w>[0-9]+)x(?<h>[0-9]+)@(?<r>[0-9.]+)"))
            | map(select((.w | tonumber) == $m.width and (.h | tonumber) == $m.height))
            | map(.r | tonumber | floor) | unique
            | if length == 0 then "\($m.refreshRate | floor) \($m.refreshRate | floor)"
              else "\(max) \(min)" end
          end'
}

# mon_remember <name> -- persist a monitor's mode/scale before disabling it.
mon_remember() {
    local name="$1" mode scale
    mode="$(mon_mode "$name")" || return 0
    [ -z "$mode" ] && return 0
    scale="$(mon_scale "$name")"
    mkdir -p "$MON_STATE_DIR"
    printf '%s,%s\n' "$mode" "$scale" > "$MON_STATE_DIR/$name"
}

# mon_recall <name> -- the remembered "mode,scale" pair, or "preferred,auto,1"
# when nothing was stored. Both forms slot straight into `monitor =`.
mon_recall() {
    local name="$1" saved
    if [ -r "$MON_STATE_DIR/$name" ]; then
        saved="$(cat "$MON_STATE_DIR/$name")"
        printf '%s, auto, %s\n' "${saved%%,*}" "${saved##*,}"
    else
        printf 'preferred, auto, 1\n'
    fi
}
