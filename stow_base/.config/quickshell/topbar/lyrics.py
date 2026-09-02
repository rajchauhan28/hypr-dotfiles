#!/usr/bin/env python3
"""Fetch lyrics for one track and emit them as JSON on stdout.

Source is LRCLIB (https://lrclib.net), which needs no API key and serves
both plain and *synced* lyrics -- the latter as standard LRC timestamps,
which is what lets the pane highlight the current line.

Deliberately not Genius: its API returns song metadata and a URL, never the
lyrics body. Getting text out of Genius means scraping the HTML page, which
its terms forbid, so there is no legitimate second provider to switch to
here yet.

Output is always a single JSON object, even for failures, so the QML side
has exactly one shape to parse:

    {"state": "ok"|"none"|"instrumental"|"error",
     "synced": bool,
     "lines": [{"t": <seconds|null>, "text": str}, ...],
     "message": str}

Results are cached under ~/.cache/quickshell/lyrics so that flipping back to
a track already looked up costs nothing and LRCLIB is not re-queried on
every pause/resume.
"""

import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "https://lrclib.net/api"
# LRCLIB asks clients to identify themselves.
UA = "quickshell-topbar-lyrics (https://github.com/rajchauhan28/hypr-dotfiles)"
TIMEOUT = 8

CACHE_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "quickshell", "lyrics",
)

# [mm:ss.xx] or [mm:ss] at the start of a line.
LRC_RE = re.compile(r"^\[(\d+):(\d+(?:[.:]\d+)?)\]\s?(.*)$")


def out(**kw):
    kw.setdefault("synced", False)
    kw.setdefault("lines", [])
    kw.setdefault("message", "")
    json.dump(kw, sys.stdout)
    sys.stdout.write("\n")
    sys.exit(0)


def get(path, params):
    url = API + path + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return json.loads(r.read().decode("utf-8"))


def parse_synced(text):
    """LRC -> [{t, text}], dropping metadata tags and keeping blank lines.

    Blank lines are kept on purpose: an instrumental break is a real gap in
    the song, and dropping it makes the highlight sit on the previous line
    for many seconds as if it were stuck.
    """
    lines = []
    for raw in text.split("\n"):
        m = LRC_RE.match(raw.strip())
        if not m:
            continue
        mins, secs, body = m.group(1), m.group(2).replace(":", "."), m.group(3)
        try:
            t = int(mins) * 60 + float(secs)
        except ValueError:
            continue
        lines.append({"t": round(t, 2), "text": body.strip()})
    lines.sort(key=lambda x: x["t"])
    return lines


def build(rec):
    if rec.get("instrumental"):
        out(state="instrumental", message="Instrumental")

    synced = rec.get("syncedLyrics") or ""
    if synced.strip():
        parsed = parse_synced(synced)
        if parsed:
            return {"state": "ok", "synced": True, "lines": parsed}

    plain = rec.get("plainLyrics") or ""
    if plain.strip():
        return {
            "state": "ok",
            "synced": False,
            "lines": [{"t": None, "text": l.strip()} for l in plain.split("\n")],
        }
    return {"state": "none", "message": "No lyrics found"}


def lookup(artist, title, album, duration):
    # The exact endpoint matches on duration too, so it returns the right
    # version of a song that has several. It 404s on any mismatch, which is
    # why the looser search below is a necessary fallback and not a nicety.
    params = {"artist_name": artist, "track_name": title}
    if album:
        params["album_name"] = album
    if duration and duration > 0:
        params["duration"] = int(duration)
    try:
        return build(get("/get", params))
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
    except urllib.error.URLError as e:
        out(state="error", message="Offline: %s" % e.reason)

    try:
        results = get("/search", {"artist_name": artist, "track_name": title})
    except urllib.error.URLError as e:
        out(state="error", message="Offline: %s" % e.reason)

    if not results:
        return {"state": "none", "message": "No lyrics found"}

    # Prefer a synced hit, and among those the closest duration -- a search
    # match with the right words but a 90s runtime is a different edit and
    # its timestamps would drift badly.
    def score(r):
        has_sync = bool((r.get("syncedLyrics") or "").strip())
        d = r.get("duration") or 0
        gap = abs(d - duration) if duration else 0
        return (not has_sync, gap)

    return build(sorted(results, key=score)[0])


def main():
    if len(sys.argv) < 3:
        out(state="error", message="usage: lyrics.py ARTIST TITLE [ALBUM] [DURATION]")

    artist = sys.argv[1].strip()
    title = sys.argv[2].strip()
    album = sys.argv[3].strip() if len(sys.argv) > 3 else ""
    try:
        duration = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0
    except ValueError:
        duration = 0.0

    if not artist or not title:
        out(state="none", message="No track playing")

    key = hashlib.sha256(
        ("\x1f".join([artist.lower(), title.lower(), album.lower(),
                      str(int(duration))])).encode("utf-8")
    ).hexdigest()[:32]
    cache = os.path.join(CACHE_DIR, key + ".json")

    if os.path.exists(cache):
        try:
            with open(cache, encoding="utf-8") as f:
                out(**json.load(f))
        except (OSError, ValueError, TypeError):
            # A truncated or stale-format cache entry must not be fatal;
            # fall through and re-fetch.
            pass

    try:
        res = lookup(artist, title, album, duration)
    except Exception as e:  # noqa: BLE001 -- any failure must still emit JSON
        out(state="error", message=str(e))

    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        tmp = cache + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(res, f)
        os.replace(tmp, cache)
    except OSError:
        pass

    out(**res)


if __name__ == "__main__":
    main()
