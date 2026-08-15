#!/usr/bin/env python3
"""Report the active Walllust wallpaper for the lockscreen."""

import json
import subprocess
from pathlib import Path


VIDEO_EXTENSIONS = {".mp4", ".webm", ".mkv", ".mov", ".avi"}
COLORS = Path.home() / ".cache" / "wal" / "colors.json"


def from_walllust() -> str:
    try:
        result = subprocess.run(
            ["walllust-cli", "status"], capture_output=True, text=True, timeout=4
        )
        for line in result.stdout.splitlines():
            if "Wallpaper:" not in line or "Directory" in line:
                continue
            value = line.split("Wallpaper:", 1)[1].strip()
            if value.startswith('Some("') and value.endswith('")'):
                value = value[6:-2]
            return value.strip('"')
    except (OSError, subprocess.SubprocessError):
        pass
    return ""


def from_pywal() -> str:
    try:
        return json.loads(COLORS.read_text()).get("wallpaper", "")
    except (OSError, ValueError):
        return ""


def main() -> None:
    value = from_walllust() or from_pywal()
    path = Path(value).expanduser()
    valid = path.is_file()
    print(json.dumps({
        "path": path.resolve().as_uri() if valid else "",
        "video": valid and path.suffix.lower() in VIDEO_EXTENSIONS,
    }))


if __name__ == "__main__":
    main()
