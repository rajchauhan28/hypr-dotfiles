#!/usr/bin/env python3
"""Power modes for a laptop: one definition, applied automatically or by hand.

    smart_gpu.py              run the AC/battery daemon (hyprland.lua starts it)
    smart_gpu.py set MODE     apply auto | battery | balanced | performance
    smart_gpu.py status       one line of JSON, read by gpu_switcher.sh

A mode bundles the power-profiles-daemon profile, the internal panel's refresh
rate, blur/shadow and -- Max Battery only -- a brightness ceiling. The daemon
and the Super+Shift+G menu both go through apply(), so "Max Battery" means the
same thing whichever of them picked it.

A mode picked by hand holds until the charger is next plugged in or pulled,
then Auto takes over again. A forgotten Performance pick therefore cannot sit
on battery for days, which is how this laptop once ended up unplugged at
165 Hz on the performance profile.

Standard library only. The previous version imported python-psutil, and an
orphan cleanup that removed the package switched all of this off without a
word: the import failed at login and nothing on screen said so.
"""

import fcntl
import json
import os
import shutil
import subprocess
import sys
import time

POLL_INTERVAL = 5        # Seconds between AC/battery checks.
THRESHOLD_BATTERY = 40   # On AC at or below this charge, Auto picks Balanced.
BRIGHTNESS_CAP = 30      # Max Battery lowers brightness to this %, never raises it.

SUPPLY_DIR = "/sys/class/power_supply"
RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/runtime-{os.getuid()}"
# Per-login on purpose: a reboot always starts back in Auto.
STATE_DIR = os.path.join(RUNTIME_DIR, "power-mode")
STATE_FILE = os.path.join(STATE_DIR, "state.json")
# hyprland.lua dofile()s this last, so a config reload keeps the active mode
# instead of snapping back to the full refresh rate with blur on.
OVERRIDES = os.path.join(STATE_DIR, "overrides.lua")
DAEMON_LOCK = os.path.join(STATE_DIR, "daemon.lock")
APPLY_LOCK = os.path.join(STATE_DIR, "apply.lock")

MODES = {
    "battery": {"label": "Max Battery", "profile": "power-saver",
                "rate": "low", "effects": False},
    "balanced": {"label": "Balanced", "profile": "balanced",
                 "rate": "high", "effects": True},
    "performance": {"label": "Performance", "profile": "performance",
                    "rate": "high", "effects": True},
}


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return ""


def run(cmd):
    """Exit code of `cmd`, or None when it could not be started at all."""
    try:
        return subprocess.run(cmd, capture_output=True, timeout=10).returncode
    except (OSError, subprocess.TimeoutExpired):
        return None


def write_atomic(path, text):
    tmp = f"{path}.tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def notify(title, message, urgency="normal"):
    run(["notify-send", "-a", "Power", "-u", urgency, "-i", "battery",
         title, message])


# ---- Power source ----------------------------------------------------------

def power_state():
    """(plugged, percent) read straight from sysfs, or None without a battery."""
    try:
        names = os.listdir(SUPPLY_DIR)
    except OSError:
        return None
    levels, statuses, sources = [], [], []
    for name in names:
        path = os.path.join(SUPPLY_DIR, name)
        kind = read(f"{path}/type")
        if kind == "Battery":
            # scope=Device marks a peripheral's battery (a wireless mouse, a
            # headset), not the laptop's own.
            if read(f"{path}/scope") == "Device":
                continue
            capacity = read(f"{path}/capacity")
            if capacity.isdigit():
                levels.append(int(capacity))
                statuses.append(read(f"{path}/status"))
        elif kind in ("Mains", "USB"):
            sources.append(read(f"{path}/online") == "1")
    if not levels:
        return None
    if sources:
        plugged = any(sources)
    else:
        # No adapter node at all: go by what the battery itself reports.
        plugged = any(s in ("Charging", "Full", "Not charging") for s in statuses)
    return plugged, round(sum(levels) / len(levels))


def auto_target(plugged, percent):
    if not plugged:
        return "battery"
    return "performance" if percent > THRESHOLD_BATTERY else "balanced"


# ---- Hyprland --------------------------------------------------------------

def hyprctl(*args):
    try:
        return subprocess.run(["hyprctl", *args], capture_output=True,
                              text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return None


def lua_eval(code):
    """Run Lua inside Hyprland. None on success, else Hyprland's error text.

    Hyprland 0.55+ on a Lua config rejects `hyprctl keyword` outright ("keyword
    can't work with non-legacy parsers"), which is why every refresh-rate and
    blur change used to fail silently. `eval` is the replacement, and unlike
    keyword it reports failure: anything but "ok" is an error.
    """
    res = hyprctl("eval", code)
    if res is None:
        return "hyprctl unavailable"
    out = res.stdout.strip()
    return None if res.returncode == 0 and out == "ok" else (out or f"exit {res.returncode}")


def lua_str(text):
    # A JSON string literal is a valid Lua one for the ASCII names used here.
    return json.dumps(text)


def internal_panel():
    """The laptop's own panel while it is lit, else None.

    Never falls back to another output: Max Battery dropping a desk monitor to
    its lowest rate is not a saving anyone asked for. A panel switched off by
    display_switcher.sh is absent from `hyprctl monitors`, so it is left alone
    too -- a monitor rule for it would turn it back on.
    """
    res = hyprctl("monitors", "-j")
    if res is None or res.returncode != 0:
        return None
    try:
        monitors = json.loads(res.stdout)
    except ValueError:
        return None
    for mon in monitors:
        if (mon.get("name", "").upper().startswith(("EDP", "LVDS", "DSI"))
                and not mon.get("disabled")):
            return mon
    return None


def refresh_bounds(monitor):
    """(highest, lowest) advertised refresh rate at the panel's current mode."""
    width, height = monitor.get("width"), monitor.get("height")
    rates = set()
    # Hyprland formats these as "1920x1200@165.00Hz".
    for mode in monitor.get("availableModes", []):
        size, _, rate = str(mode).partition("@")
        try:
            mode_w, mode_h = (int(v) for v in size.split("x"))
            rate = float(rate.rstrip("Hz"))
        except ValueError:
            continue
        if (mode_w, mode_h) == (width, height):
            rates.add(int(rate))
    if not rates:
        current = int(float(monitor.get("refreshRate", 60)))
        return current, current
    return max(rates), min(rates)


def decoration_lua(effects):
    if effects:
        # Hand blur/shadow back to whatever hyprland.lua configured; it records
        # those values in POWER_BASE. An older config without it gets "on".
        return ("local base = POWER_BASE or { blur = true, shadow = true }\n"
                "hl.config({ decoration = { blur = { enabled = base.blur }, "
                "shadow = { enabled = base.shadow } } })")
    return ("hl.config({ decoration = { blur = { enabled = false }, "
            "shadow = { enabled = false } } })")


def monitor_lua(panel, rate):
    # The panel's own resolution, position and scale: only the rate changes,
    # so an extended or mirrored layout survives the switch.
    return "hl.monitor({ output = %s, mode = %s, position = %s, scale = %s })" % (
        lua_str(panel["name"]),
        lua_str(f"{panel['width']}x{panel['height']}@{rate}"),
        lua_str(f"{panel['x']}x{panel['y']}"),
        panel.get("scale") or 1)


# ---- Everything else a mode touches ------------------------------------------

def set_profile(name):
    """Ask power-profiles-daemon for `name`; return the profile now in effect."""
    if not shutil.which("powerprofilesctl"):
        return None
    if run(["powerprofilesctl", "set", name]) == 0:
        return name
    if name == "performance":
        # Acer's firmware refuses the performance platform profile on battery
        # ("Operation not supported") and ppd then rejects the whole request,
        # leaving whatever was set before. Balanced is the most it will take.
        if run(["powerprofilesctl", "set", "balanced"]) == 0:
            return "balanced"
    try:
        return subprocess.run(["powerprofilesctl", "get"], capture_output=True,
                              text=True, timeout=10).stdout.strip() or None
    except (OSError, subprocess.TimeoutExpired):
        return None


def cap_brightness(percent):
    """Lower the backlight to `percent` if it is brighter. Never raises it."""
    if not shutil.which("brightnessctl"):
        return False
    try:
        # device,class,current,percent%,max
        info = subprocess.run(["brightnessctl", "-m", "info"], capture_output=True,
                              text=True, timeout=5).stdout
        current = int(info.split(",")[3].rstrip("%"))
    except (OSError, subprocess.TimeoutExpired, IndexError, ValueError):
        return False
    if current <= percent:
        return False
    return run(["brightnessctl", "-q", "set", f"{percent}%"]) == 0


# ---- State -------------------------------------------------------------------

def load_state():
    try:
        with open(STATE_FILE) as f:
            state = json.load(f)
    except (OSError, ValueError):
        return None
    return state if isinstance(state, dict) and state.get("mode") in MODES else None


class FileLock:
    def __init__(self, path, blocking=True):
        self.path, self.blocking, self.fd = path, blocking, None

    def __enter__(self):
        os.makedirs(STATE_DIR, exist_ok=True)
        self.fd = open(self.path, "a")
        flags = fcntl.LOCK_EX | (0 if self.blocking else fcntl.LOCK_NB)
        try:
            fcntl.flock(self.fd, flags)
        except BlockingIOError:
            self.fd.close()
            raise
        return self

    def __exit__(self, *_):
        self.fd.close()


def apply(mode, manual, plugged, note=""):
    """Put the whole of `mode` in place and record it. Caller holds APPLY_LOCK."""
    spec = MODES[mode]
    profile = set_profile(spec["profile"])

    panel = internal_panel()
    rate = None
    statements = [decoration_lua(spec["effects"])]
    if panel:
        high, low = refresh_bounds(panel)
        rate = low if spec["rate"] == "low" else high
        statements.append(monitor_lua(panel, rate))
    write_atomic(OVERRIDES,
                 f"-- Power mode \"{mode}\", written by smart_gpu.py. Regenerated on\n"
                 "-- every mode change; hyprland.lua loads it last.\n"
                 + "\n".join(statements) + "\n")

    errors = []
    err = lua_eval(statements[0])
    if err:
        errors.append(err)
    # Skip the modeset when the panel is already at the rate: it blanks the
    # screen for a moment and buys nothing.
    if panel and int(float(panel.get("refreshRate", 0))) != rate:
        err = lua_eval(statements[1])
        if err:
            errors.append(err)

    dimmed = mode == "battery" and cap_brightness(BRIGHTNESS_CAP)

    os.makedirs(STATE_DIR, exist_ok=True)
    write_atomic(STATE_FILE, json.dumps(
        {"mode": mode, "manual": manual, "plugged": plugged, "profile": profile}))

    details = []
    if rate:
        details.append(f"{rate} Hz")
    details.append("effects on" if spec["effects"] else "no blur/shadow")
    if profile:
        details.append(f"CPU {profile}")
    if dimmed:
        details.append(f"brightness {BRIGHTNESS_CAP}%")
    body = ", ".join(details) + "."
    if profile and profile != spec["profile"]:
        body += f"\nThe firmware allows {spec['profile']} only on AC; using {profile}."
    if manual:
        body += "\nHolds until you " + ("unplug." if plugged else "plug in.")
    if note:
        body = f"{note}\n{body}"
    if errors:
        body += "\nDisplay not changed: " + "; ".join(errors)
    title = f"Power: {spec['label']}" + ("" if manual else " (Auto)")
    notify(title, body, "critical" if errors else "normal")
    return not errors


# ---- Daemon ----------------------------------------------------------------

def hyprland_alive():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    return not sig or os.path.isdir(os.path.join(RUNTIME_DIR, "hypr", sig))


def daemon_running():
    if not os.path.exists(DAEMON_LOCK):
        return False
    try:
        with FileLock(DAEMON_LOCK, blocking=False):
            return False
    except BlockingIOError:
        return True


def ensure_daemon():
    """Start the daemon if it is not running; a hand-picked mode needs it to
    hand control back to Auto at the next plug/unplug."""
    if power_state() is None or daemon_running():
        return
    subprocess.Popen([os.path.abspath(__file__)], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL)


def tick(plugged, percent):
    with FileLock(APPLY_LOCK):
        state = load_state()
        note = ""
        if state and state.get("manual"):
            if state.get("plugged") == plugged:
                return               # The hand-picked mode still holds.
            note = f"{MODES[state['mode']]['label']} was picked by hand; back to Auto."
        target = auto_target(plugged, percent)
        if state is None or state.get("manual") or state["mode"] != target:
            apply(target, manual=False, plugged=plugged, note=note)


def daemon():
    if power_state() is None:
        # A desktop. Exiting is the honest response; there is nothing to follow.
        print("smart_gpu: no battery detected; nothing to tune.")
        return 0
    os.makedirs(STATE_DIR, exist_ok=True)
    lock = open(DAEMON_LOCK, "a")
    # A daemon left over from a Hyprland that just exited lets go within one
    # poll (see hyprland_alive), so wait a little before giving up.
    for _ in range(3 * POLL_INTERVAL):
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except BlockingIOError:
            time.sleep(1)
    else:
        print("smart_gpu: already running.", file=sys.stderr)
        return 0

    while hyprland_alive():
        state = power_state()
        if state is not None:
            tick(*state)
        time.sleep(POLL_INTERVAL)
    return 0


# ---- CLI -----------------------------------------------------------------

def status():
    state = power_state()
    current = load_state() or {}
    panel = internal_panel()
    high, low = refresh_bounds(panel) if panel else (None, None)
    print(json.dumps({
        "battery": state is not None,
        "plugged": state[0] if state else None,
        "percent": state[1] if state else None,
        "daemon": daemon_running(),
        "mode": current.get("mode"),
        "manual": bool(current.get("manual")),
        "auto_target": auto_target(*state) if state else None,
        "rate_high": high,
        "rate_low": low,
    }))
    return 0


def set_mode(mode):
    state = power_state()
    plugged = state[0] if state else True
    with FileLock(APPLY_LOCK):
        if mode == "auto":
            # Without a battery there is nothing to follow; Auto is Performance.
            target = auto_target(*state) if state else "performance"
            ok = apply(target, manual=False, plugged=plugged)
        else:
            ok = apply(mode, manual=True, plugged=plugged)
    ensure_daemon()
    return 0 if ok else 1


def main(argv):
    if len(argv) <= 1:
        return daemon()
    if argv[1] == "status":
        return status()
    if argv[1] == "set" and len(argv) == 3 and argv[2] in ("auto", *MODES):
        return set_mode(argv[2])
    print(f"usage: {argv[0]} [status | set auto|{'|'.join(MODES)}]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
