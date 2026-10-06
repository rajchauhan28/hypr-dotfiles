#!/usr/bin/env python3
"""Emit the wallpaper carousel's model as one JSON object on stdout:

    {"current": "<path>", "items": [{"path", "thumb", "video", "name"}, ...]}

The directory and the current wallpaper come from `walllust-cli status`, so the
carousel always agrees with the daemon wallpaper_switcher.sh drives. Thumbnails
(640px wide) are cached under ~/.cache/quickshell/wallthumbs keyed on path,
mtime and size, so only new or changed files cost a decode.
"""
import hashlib
import json
import os
import re
import subprocess
import sys

IMAGES = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif"}
VIDEOS = {".mp4", ".webm", ".mkv", ".mov"}


def daemon_status():
    try:
        out = subprocess.run(["walllust-cli", "status"], capture_output=True,
                             text=True, timeout=3).stdout
    except (OSError, subprocess.SubprocessError):
        out = ""
    cur = re.search(r'Wallpaper: Some\("(.*)"\)', out)
    wdir = re.search(r"Wallpaper Directory: (.*)", out)
    return (cur.group(1) if cur else "",
            wdir.group(1).strip() if wdir else os.path.expanduser("~/Pictures/wallpapers"))


def thumbnail(path, video, cache):
    st = os.stat(path)
    key = hashlib.sha1(f"{path}:{st.st_mtime_ns}:{st.st_size}".encode()).hexdigest()
    out = os.path.join(cache, key + ".jpg")
    if os.path.exists(out):
        return out
    if video:
        cmd = ["ffmpegthumbnailer", "-i", path, "-o", out, "-s", "640", "-t", "10%", "-q", "8"]
    else:
        cmd = ["ffmpeg", "-v", "error", "-y", "-i", path, "-frames:v", "1",
               "-vf", "scale=640:-2", "-q:v", "4", out]
    try:
        subprocess.run(cmd, capture_output=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        pass
    if os.path.exists(out):
        return out
    # An image Qt can still decode itself beats an empty card.
    return "" if video else path


def main():
    current, wdir = daemon_status()
    cache = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
                         "quickshell", "wallthumbs")
    os.makedirs(cache, exist_ok=True)

    items = []
    try:
        names = sorted(os.listdir(wdir), key=str.lower)
    except OSError:
        names = []
    for name in names:
        path = os.path.join(wdir, name)
        stem, ext = os.path.splitext(name)
        ext = ext.lower()
        if not os.path.isfile(path) or ext not in IMAGES | VIDEOS:
            continue
        video = ext in VIDEOS
        items.append({"path": path, "thumb": thumbnail(path, video, cache),
                      "video": video, "name": stem})

    json.dump({"current": current, "items": items}, sys.stdout)


if __name__ == "__main__":
    main()
