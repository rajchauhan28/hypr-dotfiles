#!/usr/bin/env python3
"""Backend for the right-edge quick-settings panel.

  syspanel.py status [--lite]         -> JSON snapshot of everything
  syspanel.py brightness <0-100>
  syspanel.py volume <0-100>          (sink)
  syspanel.py mute toggle|on|off
  syspanel.py micmute toggle
  syspanel.py sink <id>               (make an output the default)
  syspanel.py bt on|off
  syspanel.py bt connect|disconnect|forget <mac>
  syspanel.py bt scan
  syspanel.py wifi on|off
  syspanel.py wifi rescan
  syspanel.py wifi connect <ssid> [password]
  syspanel.py wifi disconnect

Every command prints a fresh `status` afterwards, so the UI never has to guess
what an action did -- it just replaces its state with whatever comes back.

Reads are deliberately cheap: the Wi-Fi list comes from NetworkManager's cache
rather than forcing a scan (a scan blocks for seconds and wakes the radio), and
Bluetooth uses `bluetoothctl devices <filter>` instead of an `info` call per
device. Explicit rescan/scan subcommands exist for when the user asks.
"""
import json
import os
import re
import subprocess
import sys

TIMEOUT = 6


def run(cmd, timeout=TIMEOUT):
    """Returns stdout, or "" for anything that fails. The panel must render
    even when a subsystem is missing, so nothing here is allowed to raise."""
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return res.stdout
    except (OSError, subprocess.SubprocessError):
        return ""


# --------------------------------------------------------------- brightness

def brightness():
    # -m is the machine-readable form: device,class,value,percent,max
    parts = run(["brightnessctl", "-m"]).strip().split("\n")[0].split(",")
    if len(parts) < 5:
        return {"available": False, "percent": 0}
    try:
        return {"available": True, "percent": int(parts[3].rstrip("%")),
                "device": parts[0]}
    except ValueError:
        return {"available": False, "percent": 0}


def set_brightness(pct):
    pct = max(1, min(100, int(pct)))     # never allow a fully dark screen
    run(["brightnessctl", "-m", "set", f"{pct}%"])


# -------------------------------------------------------------------- audio

VOL_RE = re.compile(r"Volume:\s*([0-9.]+)(\s*\[MUTED\])?")


def _volume(target):
    m = VOL_RE.search(run(["wpctl", "get-volume", target]))
    if not m:
        return {"available": False, "percent": 0, "muted": False}
    return {"available": True,
            "percent": int(round(float(m.group(1)) * 100)),
            "muted": bool(m.group(2))}


def sinks():
    """Parse `wpctl status` for output devices. The default one is starred."""
    out, seen, section = [], set(), None
    for line in run(["wpctl", "status"]).splitlines():
        stripped = line.strip(" │├└─")
        if stripped.endswith("Sinks:"):
            section = "sinks"
            continue
        if stripped.endswith(("Sources:", "Filters:", "Streams:", "Devices:")):
            section = None
            continue
        if section != "sinks":
            continue
        m = re.match(r"(\*)?\s*(\d+)\.\s+(.*?)\s*\[vol: ([0-9.]+)", line.strip(" │*"))
        if not m:
            m = re.match(r"\s*(\*)?\s*(\d+)\.\s+(.*?)\s*\[vol: ([0-9.]+)",
                         line.replace("│", " ").replace("├", " "))
        if m and m.group(2) not in seen:
            seen.add(m.group(2))
            out.append({"id": int(m.group(2)), "name": m.group(3).strip(),
                        "default": "*" in line.split(".")[0]})
    return out


def default_sink_name():
    for line in run(["wpctl", "inspect", "@DEFAULT_AUDIO_SINK@"]).splitlines():
        if "node.description" in line:
            return line.split("=", 1)[1].strip().strip('"')
    return ""


# ---------------------------------------------------------------- bluetooth

DEV_RE = re.compile(r"^Device ([0-9A-F:]{17}) (.*)$", re.I)


def _bt_devices(kind):
    out = {}
    for line in run(["bluetoothctl", "devices", kind]).splitlines():
        m = DEV_RE.match(line.strip())
        if m:
            out[m.group(1)] = m.group(2)
    return out


def bluetooth(lite=False):
    show = run(["bluetoothctl", "show"])
    if not show.strip():
        return {"available": False, "powered": False, "devices": []}

    powered = "Powered: yes" in show
    devices = []
    if powered and lite:
        # The icon strip only needs "is something connected, and what" -- one
        # call instead of three.
        for mac, name in _bt_devices("Connected").items():
            devices.append({"mac": mac, "name": name,
                            "connected": True, "paired": True})
    elif powered:
        paired = _bt_devices("Paired")
        connected = _bt_devices("Connected")
        # Anything visible but unpaired is worth offering too.
        known = dict(_bt_devices(""))
        known.update(paired)
        for mac, name in known.items():
            devices.append({"mac": mac, "name": name,
                            "connected": mac in connected,
                            "paired": mac in paired})
        devices.sort(key=lambda d: (not d["connected"], not d["paired"],
                                    d["name"].lower()))
    return {"available": True, "powered": powered, "devices": devices[:12]}


# --------------------------------------------------------------------- wifi

def wifi(lite=False):
    radio = run(["nmcli", "-t", "radio", "wifi"]).strip()
    enabled = radio.startswith("enabled")

    active_ssid, device = "", ""
    for line in run(["nmcli", "-t", "-f", "NAME,TYPE,DEVICE",
                     "connection", "show", "--active"]).splitlines():
        parts = line.split(":")
        if len(parts) >= 3 and parts[1] == "802-11-wireless":
            active_ssid, device = parts[0], parts[2]
            break

    if lite:
        # The icon strip shows only radio state and the current SSID, so skip
        # the scan list and the saved-connection enumeration entirely.
        return {"available": bool(radio), "enabled": enabled,
                "ssid": active_ssid, "device": device, "networks": []}

    saved = set()
    for line in run(["nmcli", "-t", "-f", "NAME,TYPE",
                     "connection", "show"]).splitlines():
        parts = line.rsplit(":", 1)
        if len(parts) == 2 and parts[1] == "802-11-wireless":
            saved.add(parts[0])

    nets = []
    if enabled:
        # No --rescan yes: that blocks for seconds. This reads the cache.
        raw = run(["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY",
                   "device", "wifi", "list", "--rescan", "no"])
        best = {}
        for line in raw.splitlines():
            # SSIDs may contain ':' escaped as '\:' -- split on unescaped ones.
            parts = re.split(r"(?<!\\):", line)
            if len(parts) < 4:
                continue
            ssid = parts[1].replace("\\:", ":")
            if not ssid:
                continue                       # hidden network
            try:
                signal = int(parts[2])
            except ValueError:
                signal = 0
            entry = {"ssid": ssid, "signal": signal,
                     "secure": bool(parts[3].strip()),
                     "active": parts[0] == "yes",
                     "saved": ssid in saved}
            # The same SSID shows up once per band/AP; keep the strongest.
            if ssid not in best or signal > best[ssid]["signal"]:
                best[ssid] = entry
        nets = sorted(best.values(),
                      key=lambda n: (not n["active"], -n["signal"]))[:12]

    return {"available": bool(run(["nmcli", "-t", "radio", "wifi"]).strip()),
            "enabled": enabled, "ssid": active_ssid, "device": device,
            "networks": nets}


# ------------------------------------------------------------------- status

def status(lite=False):
    out = {
        "brightness": brightness(),
        "volume": _volume("@DEFAULT_AUDIO_SINK@"),
        "mic": _volume("@DEFAULT_AUDIO_SOURCE@"),
        "bluetooth": bluetooth(lite),
        "wifi": wifi(lite),
    }
    if not lite:
        out["sinkName"] = default_sink_name()
        out["sinks"] = sinks()
    return out


# ------------------------------------------------------------------ actions

def main():
    argv = sys.argv[1:]
    cmd = argv[0] if argv else "status"
    # `lite` skips the Wi-Fi scan list, the sink list and the full Bluetooth
    # device enumeration -- everything the icon strip does not display.
    lite = "--lite" in argv
    argv = [x for x in argv if x != "--lite"]
    cmd = argv[0] if argv else "status"
    a = argv[1] if len(argv) > 1 else ""
    b = argv[2] if len(argv) > 2 else ""

    if cmd == "brightness" and a:
        set_brightness(a)

    elif cmd == "volume" and a:
        pct = max(0, min(150, int(a)))
        run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{pct/100:.2f}"])

    elif cmd == "mic" and a:
        pct = max(0, min(100, int(a)))
        run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", f"{pct/100:.2f}"])

    elif cmd == "mute":
        run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", a or "toggle"])

    elif cmd == "micmute":
        run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", a or "toggle"])

    elif cmd == "sink" and a:
        run(["wpctl", "set-default", a])

    elif cmd == "bt":
        if a in ("on", "off"):
            run(["rfkill", "unblock" if a == "on" else "block", "bluetooth"])
            run(["bluetoothctl", "power", a])
        elif a == "scan":
            # One short discovery burst; bluetoothctl needs to stay alive for it.
            run(["bluetoothctl", "--timeout", "6", "scan", "on"], timeout=10)
        elif a in ("connect", "disconnect", "remove") and b:
            run(["bluetoothctl", a, b], timeout=15)
        elif a == "forget" and b:
            run(["bluetoothctl", "remove", b], timeout=10)

    elif cmd == "wifi":
        if a in ("on", "off"):
            run(["nmcli", "radio", "wifi", a])
        elif a == "rescan":
            run(["nmcli", "device", "wifi", "rescan"], timeout=12)
        elif a == "disconnect":
            w = wifi()
            if w["device"]:
                run(["nmcli", "device", "disconnect", w["device"]], timeout=12)
        elif a == "connect" and b:
            pw = argv[3] if len(argv) > 3 else ""
            cmdline = ["nmcli", "device", "wifi", "connect", b]
            if pw:
                cmdline += ["password", pw]
            run(cmdline, timeout=25)

    print(json.dumps(status(lite)))


if __name__ == "__main__":
    main()
