#!/usr/bin/env python3
"""Adapt refresh rate, effects and CPU governor to AC/battery state.

Nothing here is specific to this laptop: the internal panel, its highest and
lowest refresh rates, and whether a battery exists at all are read from the
running system. On a machine with no battery the daemon exits immediately
instead of polling forever.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import time

POLL_INTERVAL = 5       # Seconds between AC/battery checks
THRESHOLD_BATTERY = 40  # Below this charge, stay in low-power mode even on AC

try:
    import psutil
except ModuleNotFoundError:
    print("smart_gpu: python-psutil is not installed; power tuning disabled.",
          file=sys.stderr)
    raise SystemExit(0)


def run_cmd(cmd):
    try:
        subprocess.run(cmd, shell=True, capture_output=True, timeout=10)
    except Exception:
        pass


def notify(title, message, icon="system-run"):
    run_cmd(f'notify-send "{title}" "{message}" -i {icon}')


def hypr_monitors():
    """Connected outputs as reported by Hyprland, or [] when it is not up."""
    try:
        out = subprocess.run(["hyprctl", "monitors", "-j"],
                             capture_output=True, text=True, timeout=5)
        return json.loads(out.stdout) if out.returncode == 0 else []
    except Exception:
        return []


def internal_monitor():
    """The built-in panel, matched by connector type rather than by name.

    Falls back to the first connected output so a desktop -- which has no
    eDP/LVDS/DSI connector at all -- still gets a usable target.
    """
    monitors = hypr_monitors()
    for mon in monitors:
        if mon.get("name", "").upper().startswith(("EDP", "LVDS", "DSI")):
            return mon
    return monitors[0] if monitors else None


def refresh_bounds(monitor):
    """(highest, lowest) advertised refresh rate at the panel's current mode."""
    if not monitor:
        return None, None
    width, height = monitor.get("width"), monitor.get("height")
    rates = []
    # Hyprland formats these as "1920x1200@165.00Hz" -- the trailing unit has
    # to come off before the rate will parse as a number.
    mode_re = re.compile(r"^(\d+)x(\d+)@([\d.]+)")
    for mode in monitor.get("availableModes", []):
        match = mode_re.match(str(mode))
        if not match:
            continue
        mode_w, mode_h, rate = int(match[1]), int(match[2]), float(match[3])
        if (mode_w, mode_h) == (width, height):
            rates.append(int(rate))
    if not rates:
        current = int(float(monitor.get("refreshRate", 60)))
        return current, current
    return max(rates), min(rates)


def set_refresh_rate(monitor, rate):
    """Re-apply the panel's OWN resolution at `rate`.

    The old version wrote a literal 1920x1200, which forced this laptop's
    resolution onto any other screen it ran on.
    """
    if not monitor:
        return
    name = monitor["name"]
    scale = monitor.get("scale", 1) or 1
    run_cmd(f"hyprctl keyword monitor {name}, preferred, auto, {scale}, @{rate}")


def set_perf_mode(mode):
    # `shutil.which` is the correct probe. The previous
    # `subprocess.run(["command","-v","powerprofilesctl"], shell=True)` passed
    # only "command" to the shell and always returned 0, so this branch was
    # taken whether or not the tool existed.
    if shutil.which("powerprofilesctl"):
        run_cmd(f"powerprofilesctl set {mode}")
    elif shutil.which("cpupower"):
        governor = "performance" if mode == "performance" else "powersave"
        run_cmd(f"cpupower frequency-set -g {governor}")


def set_visual_optimizations(on_battery):
    if on_battery:
        run_cmd("hyprctl keyword decoration:blur:enabled false")
        run_cmd("hyprctl keyword decoration:shadow:enabled false")
        run_cmd("brightnessctl set 30%")
    else:
        run_cmd("hyprctl keyword decoration:blur:enabled true")
        run_cmd("hyprctl keyword decoration:shadow:enabled true")


def envy_mode():
    """Current envycontrol mode, or None on a machine without it."""
    if not shutil.which("envycontrol"):
        return None
    try:
        res = subprocess.run(["envycontrol", "-q"], capture_output=True,
                             text=True, timeout=10)
        return res.stdout.strip()
    except Exception:
        return None


def main():
    if psutil.sensors_battery() is None:
        # A desktop. The old loop hit `continue` before its sleep() here and
        # span a core at 100% forever; exiting is the honest response.
        print("smart_gpu: no battery detected; nothing to tune.")
        return 0

    monitor = internal_monitor()
    rate_high, rate_low = refresh_bounds(monitor)
    print("Smart GPU Optimizer started "
          f"(monitor={monitor['name'] if monitor else 'none'}, "
          f"rates={rate_high}/{rate_low}).")

    last_plugged = None
    while True:
        battery = psutil.sensors_battery()
        if battery is None:      # Battery removed mid-session.
            time.sleep(POLL_INTERVAL)
            continue
        percent, plugged = battery.percent, battery.power_plugged

        if plugged != last_plugged:
            # Hotplugging a display changes both the panel and its rates.
            monitor = internal_monitor() or monitor
            rate_high, rate_low = refresh_bounds(monitor)

            if plugged:
                set_visual_optimizations(False)
                if percent > THRESHOLD_BATTERY:
                    notify("Power: AC",
                           f"High Performance Mode ({percent:.0f}%). {rate_high}Hz enabled.")
                    set_refresh_rate(monitor, rate_high)
                    set_perf_mode("performance")
                    mode = envy_mode()
                    if mode is not None and mode != "nvidia":
                        notify("Performance Tip",
                               "Switch to NVIDIA for max power! (Super+Shift+G)")
                else:
                    notify("Power: AC",
                           f"Charging ({percent:.0f}%). Low power until {THRESHOLD_BATTERY}%.")
            else:
                notify("Power: Battery",
                       f"Eco Mode: {rate_low}Hz, no blur.")
                set_refresh_rate(monitor, rate_low)
                set_visual_optimizations(True)
                set_perf_mode("powersave")
                if envy_mode() == "nvidia":
                    notify("Battery Tip",
                           "In NVIDIA mode! Switch to Integrated to save life.")

            last_plugged = plugged

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    raise SystemExit(main())
