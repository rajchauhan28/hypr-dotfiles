#!/usr/bin/env python3
"""Album-art accent colour for the Media tab.

    artcolor.py <artUrl>   ->  {"path": "...", "accent": "#rrggbb", "glow": "..."}

MPRIS art comes as file:// (local players) or https:// (a browser tab), so the
image is fetched into a cache keyed by URL and reused -- both for the colour and
as the source for the blurred backdrop, which is why `path` is returned.

The accent has to survive being drawn on a near-black panel, so the dominant
colour is chosen for *chroma* rather than area: cover art is mostly dark or
mostly grey, and a plain "most common pixel" picks that background every time.
"""
import colorsys
import hashlib
import json
import os
import subprocess
import sys
import urllib.parse

from PIL import Image

CACHE = os.path.expanduser("~/.cache/quickshell-topbar/art")
FALLBACK = {"path": "", "accent": "#e4e4e7", "glow": "#3f3f46"}


def fetch(url):
    """Return a local path for `url`, downloading it once if it is remote."""
    if not url:
        return ""
    if url.startswith("file://"):
        p = urllib.parse.unquote(urllib.parse.urlparse(url).path)
        return p if os.path.exists(p) else ""
    if os.path.exists(url):
        return url
    if not url.startswith(("http://", "https://")):
        return ""

    os.makedirs(CACHE, exist_ok=True)
    dest = os.path.join(CACHE, hashlib.sha1(url.encode()).hexdigest()[:16])
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return dest
    try:
        subprocess.run(["curl", "-fsSL", "--max-time", "8", "-o", dest, url],
                       capture_output=True, timeout=12)
    except (OSError, subprocess.SubprocessError):
        return ""
    return dest if os.path.exists(dest) and os.path.getsize(dest) > 0 else ""


def accent_of(path):
    """Pick a saturated, mid-bright colour, then normalise it for a dark panel."""
    with Image.open(path) as im:
        im = im.convert("RGB")
        im.thumbnail((64, 64))
        # Quantising first keeps this to a handful of candidate colours instead
        # of averaging everything into mud.
        pal = im.quantize(colors=8, method=Image.Quantize.MEDIANCUT).convert("RGB")
        counts = pal.getcolors(64 * 64) or []

    best, best_score = None, -1.0
    total = sum(c for c, _ in counts) or 1
    for count, rgb in counts:
        r, g, b = (v / 255.0 for v in rgb)
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        # Reject near-black and near-white: they carry no hue to theme with.
        if l < 0.12 or l > 0.92:
            continue
        share = count / total
        # Chroma dominates, area only breaks ties -- see module docstring.
        score = (s ** 1.5) * 3.0 + share
        if score > best_score:
            best, best_score = (h, l, s), score

    if best is None:
        return FALLBACK["accent"], FALLBACK["glow"]

    h, l, s = best
    # Force it into a band that stays legible on #101014 without glowing neon.
    accent = colorsys.hls_to_rgb(h, min(max(l, 0.58), 0.72), min(max(s, 0.45), 0.85))
    glow = colorsys.hls_to_rgb(h, 0.28, min(max(s, 0.35), 0.7))
    to_hex = lambda c: "#%02x%02x%02x" % tuple(int(round(v * 255)) for v in c)
    return to_hex(accent), to_hex(glow)


def main():
    url = sys.argv[1] if len(sys.argv) > 1 else ""
    path = fetch(url)
    if not path:
        print(json.dumps(FALLBACK))
        return 0
    try:
        accent, glow = accent_of(path)
    except Exception:
        # A truncated download or an unsupported format must not blank the tab.
        accent, glow = FALLBACK["accent"], FALLBACK["glow"]
    print(json.dumps({"path": path, "accent": accent, "glow": glow}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
