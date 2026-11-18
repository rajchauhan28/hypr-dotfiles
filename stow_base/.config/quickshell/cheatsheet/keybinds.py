#!/usr/bin/env python3
"""Keybind cheatsheet data, read live from Hyprland.

Prints one JSON line:
[{"group": str, "items": [{"keys": [str, ...], "desc": str}]}] -- `keys` lists
every combo that does the same thing (Super+W and Super+Shift+W).

The source is `hyprctl binds -j`, not hyprland.lua, so the sheet shows what is
actually bound right now. Each bind's description is "Group: Label" (see the
`d()` helper in hyprland.lua); a bind with no description is listed under
"Other" so nothing silently goes missing. Touchpad gestures come from
libinput-gestures.conf, which Hyprland does not know about.
"""
import json
import os
import re
import subprocess

# Hyprland's modmask bits, in display order.
MODS = [(64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")]

KEY_NAMES = {
    "return": "Enter", "tab": "Tab", "space": "Space", "escape": "Esc",
    "comma": ",", "period": ".", "slash": "/", "backslash": "\\",
    "bracketleft": "[", "bracketright": "]", "minus": "-", "equal": "=",
    "left": "←", "right": "→", "up": "↑", "down": "↓",
    "print": "Print", "mouse:272": "Left drag", "mouse:273": "Right drag",
    "mouse:274": "Middle click", "mouse_down": "Scroll down", "mouse_up": "Scroll up",
    "xf86audioraisevolume": "Volume Up", "xf86audiolowervolume": "Volume Down",
    "xf86audiomute": "Mute", "xf86audiomicmute": "Mic Mute",
    "xf86monbrightnessup": "Brightness Up", "xf86monbrightnessdown": "Brightness Down",
    "xf86audionext": "Next", "xf86audioprev": "Previous",
    "xf86audioplay": "Play", "xf86audiopause": "Pause", "xf86launch1": "Turbo key",
}

# Groups in the order a reader looks for them; anything else follows.
ORDER = ["Apps", "Shell", "Windows", "Workspaces", "Monitors", "Pop-ups",
         "Media", "System", "Touchpad", "Other"]


def key_label(key):
    name = KEY_NAMES.get(key.lower())
    if name:
        return name
    if key.lower().startswith("xf86"):
        return key[4:]
    return key.upper() if len(key) == 1 else key


def combo(modmask, key):
    parts = [name for bit, name in MODS if modmask & bit]
    parts.append(key_label(key))
    return " + ".join(parts)


def hypr_binds():
    try:
        out = subprocess.run(["hyprctl", "binds", "-j"], capture_output=True,
                             text=True, timeout=5).stdout
        return json.loads(out)
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return []


def gestures():
    """`gesture swipe up 3 <cmd>` lines, labelled by what the command does."""
    path = os.path.expanduser("~/.config/hypr/libinput-gestures.conf")
    rows = []
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return rows
    for line in lines:
        m = re.match(r"\s*gesture\s+(swipe|pinch)\s+(\S+)\s+(\d+)\s+(.+)", line)
        if not m:
            continue
        kind, direction, fingers, cmd = m.groups()
        if "fullscreen({ mode = 1 })" in cmd:
            desc = "Maximise"
        elif "fullscreen" in cmd:
            desc = "Fullscreen"
        else:
            desc = cmd.strip()
        rows.append((f"{fingers}-finger {kind}", direction, desc))
    # "3-finger swipe up" + "3-finger swipe down" doing the same thing -> one row.
    merged = {}
    for what, direction, desc in rows:
        merged.setdefault((what, desc), []).append(direction)
    return [{"keys": [f"{what} {'/'.join(dirs)}"], "desc": desc}
            for (what, desc), dirs in merged.items()]


def compress_numbered(items):
    """Super+1 … Super+0 "Go to workspace N" -> one "Super + 1…0" row."""
    out, runs = [], {}
    for it in items:
        m = re.match(r"^(.*\D)\s(\d+)$", it["desc"])
        km = re.match(r"^(.*?)(\d)$", it["keys"])
        if m and km:
            key = (m.group(1), km.group(1))
            if key not in runs:
                runs[key] = {"nums": [], "digits": [], "pos": len(out)}
                out.append(None)
            runs[key]["nums"].append(int(m.group(2)))
            runs[key]["digits"].append(km.group(2))
        else:
            out.append(it)
    for (desc, prefix), r in runs.items():
        if len(r["nums"]) > 2:
            out[r["pos"]] = {"keys": f"{prefix}{r['digits'][0]}…{r['digits'][-1]}",
                             "desc": f"{desc} {min(r['nums'])}–{max(r['nums'])}"}
        else:  # too short to be worth folding; keep the rows as they were
            rows = [{"keys": f"{prefix}{d}", "desc": f"{desc} {n}"}
                    for d, n in zip(r["digits"], r["nums"])]
            out[r["pos"]] = rows[0]
            out.extend(rows[1:])
    return [it for it in out if it]


def main():
    groups, seen = {}, set()
    for b in hypr_binds():
        desc = (b.get("description") or "").strip()
        group, _, label = desc.partition(": ")
        if not label:
            group, label = "Other", desc or str(b.get("dispatcher", "?"))
        keys = combo(int(b.get("modmask") or 0), str(b.get("key") or "?"))
        if (keys, label) in seen:
            continue
        seen.add((keys, label))
        groups.setdefault(group, []).append({"keys": keys, "desc": label})

    # Two keys doing the same thing (Super+W and Super+Shift+W) -> one row
    # listing both combos.
    for group, items in groups.items():
        merged = {}
        for it in compress_numbered(items):
            merged.setdefault(it["desc"], []).append(it["keys"])
        groups[group] = [{"keys": ks, "desc": d} for d, ks in merged.items()]

    g = gestures()
    if g:
        groups["Touchpad"] = g

    names = sorted(groups, key=lambda n: (ORDER.index(n) if n in ORDER else len(ORDER), n))
    print(json.dumps([{"group": n, "items": groups[n]} for n in names]))


if __name__ == "__main__":
    main()
