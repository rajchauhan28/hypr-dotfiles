#!/usr/bin/env bash
# Power-mode and GPU-mode picker (Super+Shift+G).
#
# Power modes are applied by smart_gpu.py -- the same code the AC/battery
# daemon runs -- so a mode picked here and one picked automatically are
# identical. A hand-picked mode holds until the charger is next plugged in or
# pulled, then Auto takes over again.
#
# The GPU half only applies to an NVIDIA Optimus laptop with envycontrol. On
# an AMD or Intel-only machine those entries are omitted rather than offered
# and then failing, and the menu is just the power modes.

set -u
SMART="$HOME/.config/hypr/smart_gpu.py"
# "<running-mode> <selected-mode> <boot_id>": a GPU switch made in this boot
# that only takes effect at the next one. Not in XDG_RUNTIME_DIR, because a
# logout clears that and a logout does not apply the switch.
GPU_PENDING="${XDG_STATE_HOME:-$HOME/.local/state}/power-mode/gpu-pending"

# envycontrol's integrated mode does not merely blacklist the driver -- it
# writes a udev rule that does ATTR{remove}="1" on every 10de device at boot,
# so the card leaves the PCI bus entirely and lspci goes blind. Gating the
# menu on lspci alone therefore hides the Hybrid/NVIDIA entries at exactly the
# moment they are the only way back. Those two files are only ever generated
# on a machine that has a dGPU, so they stand in as proof of one.
has_nvidia() {
    lspci -nn 2>/dev/null | grep -qi '\[10de:' && return 0
    # envycontrol records the dGPU's bus address when it first detects one, and
    # that survives every mode and every reboot. It is the only signal that
    # holds in the gap between switching to hybrid -- which deletes both files
    # below -- and the reboot that actually puts the card back on the bus.
    envycontrol --cache-query 2>/dev/null | grep -q nvidia_gpu_pci_bus && return 0
    [ -e /etc/udev/rules.d/50-remove-nvidia.rules ] && return 0
    [ -e /etc/modprobe.d/blacklist-nvidia.conf ] && return 0
    return 1
}
has_envycontrol() { command -v envycontrol >/dev/null 2>&1; }
# The mode envycontrol has CONFIGURED, read from the files it writes. Right
# after a switch that is the new mode, not the one the machine is running.
configured_gpu() { envycontrol --query 2>/dev/null | tr -d '[:space:]'; }
boot_id() { cat /proc/sys/kernel/random/boot_id 2>/dev/null; }

# Sets RUNNING_GPU and SELECTED_GPU. They differ only while a switch waits for
# a reboot; a marker from an earlier boot has been applied and is dropped.
read_gpu_state() {
    local running selected id
    SELECTED_GPU="$(configured_gpu)"
    RUNNING_GPU="$SELECTED_GPU"
    [ -r "$GPU_PENDING" ] || return 0
    read -r running selected id <"$GPU_PENDING"
    if [ "$id" = "$(boot_id)" ] && [ "$running" != "$SELECTED_GPU" ]; then
        RUNNING_GPU="$running"
    else
        rm -f "$GPU_PENDING"
    fi
}

switch_gpu() {
    local mode="$1" bin powerd rc
    # pkexec, not sudo: this script is launched from a dmenu with no
    # controlling terminal, so sudo has nothing to prompt on. Resolve the path
    # first: pkexec sanitises the environment, so PATH may not survive.
    bin="$(command -v envycontrol)" || {
        notify-send "GPU Switch" "envycontrol not found."
        return 1
    }
    local args=(-s "$mode")
    # Without --rtd3 envycontrol writes no runtime-D3 config at all, and the
    # dGPU never powers down in hybrid mode -- ~5 W for nothing. 3 is
    # fine-grained D3 for Ampere and newer (this is an RTX 4050).
    [ "$mode" = hybrid ] && args+=(--rtd3 3)

    # nvidia-powerd (Dynamic Boost) keeps /dev/nvidia0 open for as long as it
    # runs, so the dGPU can never runtime-suspend. It only pays off when the
    # dGPU is on anyway, i.e. NVIDIA mode; every other mode turns it off. Done
    # in the same pkexec as envycontrol so a switch costs one password prompt.
    powerd=true
    if systemctl cat nvidia-powerd >/dev/null 2>&1; then
        if [ "$mode" = nvidia ]; then
            powerd="systemctl enable nvidia-powerd"
        else
            powerd="systemctl disable --now nvidia-powerd"
        fi
    fi

    notify-send "GPU Switch" "Switching to $mode mode..."
    # shellcheck disable=SC2016 # $0/$@ are expanded by the root shell.
    pkexec /bin/sh -c '"$0" "$@" || exit $?; '"$powerd" "$bin" "${args[@]}"
    rc=$?
    case "$rc" in
        126) notify-send "GPU Switch" "Cancelled at the authentication prompt."; return 1 ;;
        127) notify-send "GPU Switch" "Not authorised to run envycontrol."; return 1 ;;
    esac
    # Judge by what envycontrol configured, not its exit code: it logs an
    # error and carries on when nvidia-persistenced is masked (deliberately,
    # on this laptop), and the mode is still switched.
    if [ "$(configured_gpu)" != "$mode" ]; then
        notify-send -u critical "GPU Switch" \
            "envycontrol failed (exit $rc); still configured for $(configured_gpu)."
        return 1
    fi

    if [ "$mode" = "$RUNNING_GPU" ]; then
        rm -f "$GPU_PENDING"
        notify-send "GPU Switch" "Back to $mode, the mode already running. No reboot needed."
        return 0
    fi
    mkdir -p "$(dirname "$GPU_PENDING")"
    printf '%s %s %s\n' "$RUNNING_GPU" "$mode" "$(boot_id)" >"$GPU_PENDING"
    # A reboot, not a logout. Leaving integrated mode means dropping the udev
    # rule that removes the card from the PCI bus and rebuilding the initramfs
    # without the blacklist; neither is re-read until boot.
    notify-send -u critical "GPU Switch" \
        "Mode set to $mode. REBOOT to apply -- a logout is not enough. Super+Shift+G has a Reboot entry."
}

# ---- Build the menu --------------------------------------------------------
STATUS="$("$SMART" status 2>/dev/null)" || STATUS='{}'
st() { jq -r "$1 | if . == null then \"\" else tostring end" <<<"$STATUS" 2>/dev/null; }
BATTERY="$(st .battery)"
PLUGGED="$(st .plugged)"
DAEMON="$(st .daemon)"
MODE="$(st .mode)"
MANUAL="$(st .manual)"
AUTO_TARGET="$(st .auto_target)"
RATE_HIGH="$(st .rate_high)"
RATE_LOW="$(st .rate_low)"

declare -A ACTION
labels=()
add() { labels+=("$1"); ACTION["$1"]="$2"; }
# Display-only marker for whatever is live, so the menu answers "what am I on
# now?" without a trip to a terminal.
mark() { if [ "$1" = "$2" ]; then printf '  (%s)' "${3:-active}"; fi; }
hz() { [ -n "$1" ] && printf '%s Hz, ' "$1"; }

pretty() {
    case "$1" in
        battery) echo "Max Battery" ;; balanced) echo "Balanced" ;;
        performance) echo "Performance" ;; *) echo "$1" ;;
    esac
}

# A daemon that died is exactly how battery tuning once vanished for eleven
# days without a sign, so say so at the top. Any power pick also restarts it.
if [ "$BATTERY" = true ] && [ "$DAEMON" != true ]; then
    add "! Automatic power switching is NOT running - select to restart" "power:auto"
fi

if [ "$MANUAL" = true ]; then active_power="$MODE"; else active_power=auto; fi
perf_note="max CPU"
[ "$PLUGGED" = false ] && perf_note="CPU capped at Balanced until plugged in"

if [ "$BATTERY" = true ]; then
    auto_now=""
    [ -n "$AUTO_TARGET" ] && auto_now=" (now $(pretty "$AUTO_TARGET"))"
    add "Power: Auto - follows the charger${auto_now}$(mark auto "$active_power")" "power:auto"
fi
add "Power: Max Battery - $(hz "$RATE_LOW")no blur or glass, power-saver, dimmed$(mark battery "$active_power")" "power:battery"
add "Power: Balanced - $(hz "$RATE_HIGH")effects on, balanced CPU$(mark balanced "$active_power")" "power:balanced"
add "Power: Performance - $(hz "$RATE_HIGH")effects on, ${perf_note}$(mark performance "$active_power")" "power:performance"

if has_nvidia && has_envycontrol; then
    read_gpu_state
    gpu_mark() {
        if [ "$RUNNING_GPU" != "$SELECTED_GPU" ]; then
            mark "$1" "$RUNNING_GPU" "running now"
            mark "$1" "$SELECTED_GPU" "after reboot"
        else
            mark "$1" "$RUNNING_GPU"
        fi
    }
    add "GPU: Integrated - iGPU only, dGPU off, best battery$(gpu_mark integrated)" "gpu:integrated"
    add "GPU: Hybrid - dGPU sleeps until an app uses it$(gpu_mark hybrid)" "gpu:hybrid"
    add "GPU: NVIDIA - dGPU always on, gaming$(gpu_mark nvidia)" "gpu:nvidia"
    if [ "$RUNNING_GPU" != "$SELECTED_GPU" ]; then
        add "Reboot now to finish switching to $SELECTED_GPU" "reboot"
    fi
fi

CHOICE=$(printf '%s\n' "${labels[@]}" | "$HOME/.local/bin/qs-dmenu" --dmenu -p "Power & GPU")
[ -z "$CHOICE" ] && exit 0
action="${ACTION[$CHOICE]:-}"

case "$action" in
    power:*)
        "$SMART" set "${action#power:}" ;;
    gpu:*)
        mode="${action#gpu:}"
        if [ "$mode" = "$SELECTED_GPU" ]; then
            notify-send "GPU Switch" "Already set to $mode."
        else
            switch_gpu "$mode"
        fi ;;
    reboot)
        systemctl reboot ;;
esac
