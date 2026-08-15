#!/usr/bin/env python3
"""Import a lockscreen avatar into Quickshell's managed assets directory."""

import hashlib
import os
import shutil
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse


ALLOWED = {".png", ".jpg", ".jpeg", ".webp", ".svg"}
ASSET_DIR = Path.home() / ".config" / "quickshell" / "assets"


def source_path(value: str) -> Path:
    parsed = urlparse(value)
    if parsed.scheme == "file":
        return Path(unquote(parsed.path))
    return Path(value).expanduser()


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: avatar.py <image>", file=sys.stderr)
        return 2

    source = source_path(sys.argv[1]).resolve()
    suffix = source.suffix.lower()
    if not source.is_file() or suffix not in ALLOWED:
        print("Select a PNG, JPEG, WebP, or SVG image.", file=sys.stderr)
        return 1

    digest = hashlib.sha256(source.read_bytes()).hexdigest()[:12]
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    destination = ASSET_DIR / f"avatar-{digest}{suffix}"

    if not destination.exists():
        temporary = ASSET_DIR / f".{destination.name}.tmp"
        shutil.copyfile(source, temporary)
        os.replace(temporary, destination)

    print(destination.as_uri())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
