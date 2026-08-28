#!/usr/bin/env python3
"""Rescale the Quickshell suite's pixel geometry to the machine's screen.

Every number in settings.json was tuned on a 1920x1200 laptop panel. This
rewrites the pixel-valued ones for the detected screen and leaves everything
else -- colours, counts, timeouts, fractions -- exactly as shipped.

Two things make this less naive than multiplying by a resolution ratio:

* It scales by LOGICAL resolution (pixels / compositor scale). A 4K panel run
  at scale 2 presents 1920x1080 logical pixels, so the shell must NOT double;
  the same panel at scale 1 must. Using raw pixels gets that backwards.

* Panel sizes are clamped to the screen afterwards. The topbar dashboard is
  1280x720 at baseline, which simply does not fit on a 1366x768 display no
  matter what the ratio says.

Usage: SCREEN_W=.. SCREEN_H=.. SCREEN_SCALE=.. scale_settings.py <settings.json>
"""

import json
import os
import sys

# The screen the shipped geometry was authored on.
BASE_W, BASE_H = 1920, 1200

# Only these keys are pixel geometry. Anything not listed -- hotspot*Fraction,
# previewMaxTiles, maxVisible, bodyMaxLines, timeout*, and the whole palette --
# is a count, a ratio or a colour and must survive untouched.
SCALABLE = {
    "dock": ["iconSlot", "iconSize", "dockPadding", "hotspotHeight",
             "radiusPanel", "cornerFillet", "edgeLine",
             "previewTileW", "previewTileH"],
    "topbar": ["panelWidth", "panelHeight", "hotspotHeight", "radiusPanel",
               "cornerFillet", "edgeLine", "gap", "cardPadding"],
    "sidepanel": ["iconSlot", "stripPadding", "panelWidth", "hotspotWidth",
                  "radiusPanel", "cornerFillet", "edgeLine", "osdWidth"],
    "notifications": ["panelWidth", "bottomMargin", "cardPadding", "iconSize",
                      "radiusPanel", "radiusSmall", "cornerFillet"],
    "leftbar": ["barWidth", "iconSlot"],
}

# Below these the shell stops being usable: a 6px icon is not a small icon, it
# is an invisible one, and a 1px edge line disappears entirely.
#
# Floors are keyed by (section, key), NOT by key alone. "panelWidth" means a
# 1280px dashboard in `topbar` and a 50px vertical strip in `sidepanel`; one
# shared floor would inflate the strip to the dashboard's minimum.
FLOORS = {
    ("dock", "iconSlot"): 24,
    ("dock", "iconSize"): 16,
    ("dock", "dockPadding"): 4,
    ("dock", "hotspotHeight"): 6,
    ("dock", "radiusPanel"): 4,
    ("dock", "cornerFillet"): 4,
    ("dock", "edgeLine"): 2,
    ("dock", "previewTileW"): 96,
    ("dock", "previewTileH"): 60,

    ("topbar", "panelWidth"): 480,
    ("topbar", "panelHeight"): 320,
    ("topbar", "hotspotHeight"): 6,
    ("topbar", "radiusPanel"): 4,
    ("topbar", "cornerFillet"): 4,
    ("topbar", "edgeLine"): 2,
    ("topbar", "gap"): 4,
    ("topbar", "cardPadding"): 6,

    ("sidepanel", "iconSlot"): 24,
    ("sidepanel", "stripPadding"): 2,
    ("sidepanel", "panelWidth"): 30,
    ("sidepanel", "hotspotWidth"): 6,
    ("sidepanel", "radiusPanel"): 4,
    ("sidepanel", "cornerFillet"): 4,
    ("sidepanel", "edgeLine"): 2,
    ("sidepanel", "osdWidth"): 80,

    ("notifications", "panelWidth"): 240,
    ("notifications", "bottomMargin"): 8,
    ("notifications", "cardPadding"): 6,
    ("notifications", "iconSize"): 16,
    ("notifications", "radiusPanel"): 4,
    ("notifications", "radiusSmall"): 3,
    ("notifications", "cornerFillet"): 4,

    ("leftbar", "barWidth"): 32,
    ("leftbar", "iconSlot"): 20,
}


def factor(logical_w, logical_h):
    """Uniform scale that keeps the widest panel on screen.

    min() of the two axes rather than an average: the vertical axis is what
    runs out first on a 16:9 screen, and overshooting there pushes the
    dashboard off the bottom edge.
    """
    return min(logical_w / BASE_W, logical_h / BASE_H)


def main():
    if len(sys.argv) != 2:
        print("usage: scale_settings.py <settings.json>", file=sys.stderr)
        return 2
    path = sys.argv[1]

    try:
        width = int(float(os.environ["SCREEN_W"]))
        height = int(float(os.environ["SCREEN_H"]))
        scale = float(os.environ.get("SCREEN_SCALE") or 1) or 1.0
    except (KeyError, ValueError):
        print("scale_settings: SCREEN_W/SCREEN_H not set", file=sys.stderr)
        return 1
    if width <= 0 or height <= 0:
        print("scale_settings: implausible screen size", file=sys.stderr)
        return 1

    logical_w, logical_h = width / scale, height / scale
    ratio = factor(logical_w, logical_h)

    # Clamp: below 0.55 the shell is unreadable, above 2.5 it is cartoonish,
    # and anything outside that range is more likely a detection error.
    ratio = max(0.55, min(2.5, ratio))

    try:
        with open(path) as handle:
            cfg = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        print("scale_settings: cannot read %s (%s)" % (path, exc), file=sys.stderr)
        return 1

    # A near-baseline screen needs no rewrite at all; skipping it keeps the
    # file byte-identical to the shipped defaults.
    if abs(ratio - 1.0) < 0.02:
        print("scale_settings: %dx%d@%g is the baseline; left unchanged"
              % (width, height, scale))
        return 0

    for section, keys in SCALABLE.items():
        block = cfg.get(section)
        if not isinstance(block, dict):
            continue
        for key in keys:
            value = block.get(key)
            if not isinstance(value, (int, float)) or isinstance(value, bool):
                continue
            floor = FLOORS.get((section, key), 1)
            block[key] = max(floor, int(round(value * ratio)))

    # The dashboard is a fixed-size window, not a bar: after scaling it still
    # has to fit, with a margin so it never touches the screen edges.
    topbar = cfg.get("topbar")
    if isinstance(topbar, dict):
        if isinstance(topbar.get("panelWidth"), (int, float)):
            topbar["panelWidth"] = int(min(topbar["panelWidth"], logical_w * 0.92))
        if isinstance(topbar.get("panelHeight"), (int, float)):
            topbar["panelHeight"] = int(min(topbar["panelHeight"], logical_h * 0.86))

    # The notification stack sits at a screen edge; keep it off the far side.
    notifications = cfg.get("notifications")
    if isinstance(notifications, dict) and isinstance(notifications.get("panelWidth"), (int, float)):
        notifications["panelWidth"] = int(min(notifications["panelWidth"], logical_w * 0.45))

    cfg["_scaled"] = {
        "screen": "%dx%d" % (width, height),
        "compositorScale": scale,
        "factor": round(ratio, 3),
        "baseline": "%dx%d" % (BASE_W, BASE_H),
        "note": "Written by Install.sh. Edit freely in the Settings app (Super+comma).",
    }
    cfg.pop("_baseline", None)

    # Write through a temporary file: the panels watch settings.json and would
    # otherwise reload a half-written document.
    tmp = path + ".tmp"
    with open(tmp, "w") as handle:
        json.dump(cfg, handle, indent=2)
        handle.write("\n")
    os.replace(tmp, path)

    print("scale_settings: %dx%d@%g -> factor %.3f" % (width, height, scale, ratio))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
