#!/usr/bin/env python3
"""Wallpaper inventory for the topbar panel.

  wallpapers.py list          -> JSON {current, items:[{path,name,ext,w,h,thumb,video}]}
  wallpapers.py set <path>    -> applies via walllust-cli, prints the new state

Metadata (dimensions) and video thumbnails are cached on disk keyed by path and
mtime, so the slow probing only happens once per wallpaper. Videos get a frame
extracted with ffmpeg; images are their own thumbnail.
"""
import hashlib
import json
import os
import subprocess
import sys

HOME = os.path.expanduser("~")
WALL_DIR = os.path.join(HOME, "Pictures/wallpapers")
CACHE_DIR = os.path.join(HOME, ".cache/quickshell-topbar")
THUMB_DIR = os.path.join(CACHE_DIR, "thumbs")
META_CACHE = os.path.join(CACHE_DIR, "wallpaper-meta.json")
COLORS = os.path.join(HOME, ".cache/wal/colors.json")

IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}
VIDEO_EXT = {".mp4", ".webm", ".mkv", ".mov", ".avi"}


def load_cache():
    try:
        with open(META_CACHE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_cache(cache):
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(META_CACHE, "w") as f:
            json.dump(cache, f)
    except OSError:
        pass


def probe_image(path):
    try:
        res = subprocess.run(["identify", "-format", "%w %h", path + "[0]"],
                             capture_output=True, text=True, timeout=8)
        w, h = res.stdout.strip().split()[:2]
        return int(w), int(h)
    except (OSError, ValueError, IndexError, subprocess.SubprocessError):
        return 0, 0


def probe_video(path):
    try:
        res = subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "v:0",
             "-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", path],
            capture_output=True, text=True, timeout=10)
        w, h = res.stdout.strip().split("x")[:2]
        return int(w), int(h)
    except (OSError, ValueError, IndexError, subprocess.SubprocessError):
        return 0, 0


def video_thumb(path):
    """Extract a frame once, cached by path+mtime."""
    os.makedirs(THUMB_DIR, exist_ok=True)
    try:
        mtime = int(os.path.getmtime(path))
    except OSError:
        mtime = 0
    key = hashlib.sha1(f"{path}:{mtime}".encode()).hexdigest()[:16]
    out = os.path.join(THUMB_DIR, key + ".jpg")
    if os.path.exists(out):
        return out
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-ss", "3", "-i", path,
             "-frames:v", "1", "-vf", "scale=480:-1", out],
            capture_output=True, timeout=25)
    except (OSError, subprocess.SubprocessError):
        return ""
    return out if os.path.exists(out) else ""


def current_wallpaper():
    """walllust-cli reports the real path; the stow symlink means it may not
    match the entries under ~/Pictures, so compare by basename too."""
    try:
        res = subprocess.run(["walllust-cli", "status"],
                             capture_output=True, text=True, timeout=5)
        for line in res.stdout.splitlines():
            if "Wallpaper:" in line and "Directory" not in line:
                part = line.split("Wallpaper:", 1)[1].strip()
                if part.startswith('Some("') and part.endswith('")'):
                    return part[6:-2]
                return part.strip('"')
    except (OSError, subprocess.SubprocessError):
        pass
    # Fall back to whatever pywal last recorded.
    try:
        with open(COLORS) as f:
            return json.load(f).get("wallpaper", "")
    except (OSError, ValueError):
        return ""


def palette():
    try:
        with open(COLORS) as f:
            data = json.load(f)
        cols = data.get("colors", {})
        return [cols[f"color{i}"] for i in range(16) if f"color{i}" in cols]
    except (OSError, ValueError, KeyError):
        return []


def listing():
    cache = load_cache()
    dirty = False
    items = []

    try:
        names = sorted(os.listdir(WALL_DIR))
    except OSError:
        names = []

    for name in names:
        path = os.path.join(WALL_DIR, name)
        if not os.path.isfile(path):
            continue
        ext = os.path.splitext(name)[1].lower()
        # walllust-cli list happily returns .zip/.rdp files that happen to sit
        # in the folder; only real media belongs in the picker.
        if ext not in IMAGE_EXT and ext not in VIDEO_EXT:
            continue

        try:
            mtime = int(os.path.getmtime(path))
        except OSError:
            mtime = 0
        key = f"{path}:{mtime}"
        entry = cache.get(key)

        if entry is None:
            is_video = ext in VIDEO_EXT
            w, h = probe_video(path) if is_video else probe_image(path)
            entry = {
                "w": w,
                "h": h,
                "video": is_video,
                "thumb": video_thumb(path) if is_video else path,
            }
            cache[key] = entry
            dirty = True

        items.append({
            "path": path,
            "name": os.path.splitext(name)[0],
            "ext": ext.lstrip("."),
            "w": entry["w"],
            "h": entry["h"],
            "video": entry["video"],
            "thumb": entry["thumb"],
            "size": os.path.getsize(path) if os.path.exists(path) else 0,
        })

    if dirty:
        # Drop stale keys so the cache doesn't grow without bound.
        live = {f"{i['path']}:{int(os.path.getmtime(i['path']))}" for i in items
                if os.path.exists(i["path"])}
        save_cache({k: v for k, v in cache.items() if k in live})

    cur = current_wallpaper()
    cur_base = os.path.basename(cur) if cur else ""
    index = next((n for n, i in enumerate(items)
                  if os.path.basename(i["path"]) == cur_base), -1)

    return {"current": cur, "index": index, "items": items, "palette": palette()}


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "set" and len(sys.argv) >= 3:
        subprocess.run(["walllust-cli", "set", sys.argv[2]],
                       capture_output=True, timeout=30)
    print(json.dumps(listing()))


if __name__ == "__main__":
    main()
