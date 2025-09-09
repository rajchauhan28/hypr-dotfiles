#!/usr/bin/env python3
import json
import subprocess

def pc(*args):
    try:
        return subprocess.check_output(["playerctl", *args], stderr=subprocess.DEVNULL).decode().strip()
    except Exception:
        return ""

def safe_json(obj):
    # Ensure only one line with a compact JSON object
    return json.dumps(obj, separators=(",", ":"))

def main():
    title = pc("metadata", "title")
    artist = pc("metadata", "artist")
    status = pc("status")
    cover = pc("metadata", "mpris:artUrl")

    # Normalize fields
    artist = artist or ""
    state = "playing" if status.lower() == "playing" else ("paused" if status.lower() == "paused" else "stopped")
    icon = "" if state == "playing" else ("" if state == "paused" else "")

    if not title:
        out = {
            "text": " No music",
            "tooltip": "",
            "class": ["media", "stopped"]
        }
        print(safe_json(out))
        return

    text = f"{icon} {title}" + (f" - {artist}" if artist else "")
    if len(text) > 20:
        text = text[:17] + "..."
    tooltip = f"<b>{title}</b>" + (f"{artist}" if artist else "")

    out = {
        "text": text,
        "tooltip": tooltip,
        "class": ["media", state],
        # Uncomment if using percentage in formats
        # "percentage": 0
        # Optionally pass cover URL as alt text for CSS hooks
        # "alt": cover or ""
    }
    print(safe_json(out))

if __name__ == "__main__":
    main()
