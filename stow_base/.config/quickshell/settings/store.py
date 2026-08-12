#!/usr/bin/env python3
"""Atomic JSON writer for the settings app.

    store.py <path> <json-text>

The panels file-watch these files, so a half-written file would briefly parse
as garbage. Writing to a tempfile in the same directory and os.replace()-ing it
makes the swap atomic: a watcher sees either the old file or the new one.
The payload is parsed before anything is written, so a malformed argument can
never truncate a good config.
"""

import json
import os
import sys
import tempfile


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: store.py <path> <json>", file=sys.stderr)
        return 2

    path, payload = sys.argv[1], sys.argv[2]

    try:
        obj = json.loads(payload)
    except json.JSONDecodeError as exc:
        print(f"refusing to write malformed json: {exc}", file=sys.stderr)
        return 1

    directory = os.path.dirname(os.path.abspath(path))
    os.makedirs(directory, exist_ok=True)

    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".settings-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(obj, handle, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    except Exception:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise

    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
