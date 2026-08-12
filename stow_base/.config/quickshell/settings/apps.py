#!/usr/bin/env python3
"""List installed desktop entries as one JSON line, for the settings app's
"add a pinned app" picker.

Quickshell's own DesktopEntries singleton came back empty in this build, and we
need more control anyway: the dock matches running windows by Wayland app_id,
which is what StartupWMClass records when it differs from the file's id.

Output: {"apps": [{"name", "exec", "icon", "class"}, ...]} sorted by name.
"""

import json
import os
import sys

DESKTOP_ID_SUFFIX = ".desktop"

# Field codes a launcher is supposed to expand; we launch with no arguments, so
# they must be stripped or the app gets a literal "%U" as its first argument.
FIELD_CODES = {"%f", "%F", "%u", "%U", "%d", "%D", "%n", "%N",
               "%i", "%c", "%k", "%v", "%m"}


def data_dirs():
    """Every applications/ directory, highest precedence first."""
    home = os.path.expanduser("~/.local/share")
    dirs = [os.environ.get("XDG_DATA_HOME", home)]
    raw = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    dirs.extend(p for p in raw.split(":") if p)
    return [os.path.join(d, "applications") for d in dirs]


def parse(path):
    """Read the [Desktop Entry] group only. Later groups are actions, and their
    Name=/Exec= would otherwise overwrite the entry's own."""
    entry = {}
    in_group = False
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                line = line.strip()
                if line.startswith("["):
                    in_group = line == "[Desktop Entry]"
                    continue
                if not in_group or "=" not in line or line.startswith("#"):
                    continue
                key, _, value = line.partition("=")
                key = key.strip()
                # Skip localised keys (Name[de]) so the C locale value wins.
                if "[" not in key:
                    entry[key] = value.strip()
    except OSError:
        return None
    return entry


def clean_exec(value):
    parts = []
    for token in value.split():
        if token in FIELD_CODES:
            continue
        parts.append(token)
    # `env FOO=bar app` and friends: keep as-is, it still launches correctly.
    return " ".join(parts)


def collect():
    seen = set()
    apps = []

    for directory in data_dirs():
        if not os.path.isdir(directory):
            continue
        for name in sorted(os.listdir(directory)):
            if not name.endswith(DESKTOP_ID_SUFFIX):
                continue
            # First directory wins, per XDG precedence.
            if name in seen:
                continue
            seen.add(name)

            entry = parse(os.path.join(directory, name))
            if not entry:
                continue
            if entry.get("Type", "Application") != "Application":
                continue
            if entry.get("NoDisplay", "").lower() == "true":
                continue
            if entry.get("Hidden", "").lower() == "true":
                continue
            if not entry.get("Exec"):
                continue

            app_id = name[: -len(DESKTOP_ID_SUFFIX)]
            apps.append({
                "name": entry.get("Name") or app_id,
                "exec": clean_exec(entry["Exec"]),
                "icon": entry.get("Icon") or app_id,
                # The dock matches windows on this; StartupWMClass is the
                # authoritative app_id when it disagrees with the file name.
                "class": entry.get("StartupWMClass") or app_id,
            })

    apps.sort(key=lambda a: a["name"].lower())
    return apps


def main():
    json.dump({"apps": collect()}, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
