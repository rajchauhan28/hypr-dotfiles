#!/usr/bin/env python3
"""Durable store for calendar bookmarks.

  calendar_store.py list
  calendar_store.py add <YYYY-MM-DD> <text>
  calendar_store.py delete <YYYY-MM-DD> <index>

All commands print the full store as JSON.

The primary file is the clock widget's existing events.json, so notes written
here show up there and vice versa — one database, not two competing ones.

Durability:
  * writes are atomic (temp file in the same directory + os.replace), so a
    crash mid-write can never leave a half-written JSON behind;
  * before the first write of each day the current good file is copied to
    ~/.local/quickshell-calendar.json.bak, giving a rolling one-per-day
    snapshot;
  * on load, a missing or corrupt primary falls back to that backup and
    immediately restores it.
"""
import json
import os
import shutil
import sys
import tempfile
import time

PRIMARY = os.path.expanduser("~/.config/quickshell/widgets/clock/events.json")
BACKUP = os.path.expanduser("~/.local/quickshell-calendar.json.bak")


def _read(path):
    """Returns the parsed dict, or None if unreadable/corrupt/wrong shape."""
    try:
        with open(path) as f:
            data = json.load(f)
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def load():
    data = _read(PRIMARY)
    if data is not None:
        return data

    # Primary is gone or corrupt — fall back to the daily backup and put it
    # back in place so the next read is healthy again.
    recovered = _read(BACKUP)
    if recovered is not None:
        _write_atomic(PRIMARY, recovered)
        return recovered
    return {}


def _write_atomic(path, data):
    directory = os.path.dirname(path)
    try:
        os.makedirs(directory, exist_ok=True)
    except OSError:
        return False
    try:
        # Same filesystem as the target, so os.replace is atomic.
        fd, tmp = tempfile.mkstemp(dir=directory, prefix=".events-", suffix=".tmp")
        try:
            with os.fdopen(fd, "w") as f:
                json.dump(data, f, indent=2)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, path)
        except BaseException:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise
    except OSError:
        return False
    return True


def rotate_backup():
    """Refresh the backup once per day, from the last known-good primary."""
    today = time.strftime("%Y-%m-%d")
    try:
        if os.path.exists(BACKUP):
            stamp = time.strftime("%Y-%m-%d", time.localtime(os.path.getmtime(BACKUP)))
            if stamp == today:
                return          # already rotated today
    except OSError:
        pass

    # Only snapshot a primary that parses — never overwrite a good backup with
    # a corrupt file, which would destroy the very thing we are protecting.
    if _read(PRIMARY) is None:
        return
    try:
        os.makedirs(os.path.dirname(BACKUP), exist_ok=True)
        shutil.copy2(PRIMARY, BACKUP)
    except OSError:
        pass


def save(data):
    rotate_backup()
    _write_atomic(PRIMARY, data)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    data = load()

    if cmd == "add" and len(sys.argv) >= 4:
        key = sys.argv[2]
        text = " ".join(sys.argv[3:]).strip()
        if text:
            data.setdefault(key, [])
            if text not in data[key]:
                data[key].append(text)
            save(data)

    elif cmd == "delete" and len(sys.argv) >= 4:
        key = sys.argv[2]
        try:
            idx = int(sys.argv[3])
        except ValueError:
            idx = -1
        if key in data and 0 <= idx < len(data[key]):
            data[key].pop(idx)
            if not data[key]:
                del data[key]
            save(data)

    print(json.dumps(data))


if __name__ == "__main__":
    main()
