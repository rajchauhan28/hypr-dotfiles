#!/usr/bin/env python3
"""List local interactive accounts and their profile images."""

import json
import os
import pwd
from pathlib import Path


BLOCKED_SHELLS = {"/bin/false", "/usr/bin/false", "/sbin/nologin", "/usr/bin/nologin"}


def uid_min() -> int:
    try:
        for line in Path("/etc/login.defs").read_text().splitlines():
            fields = line.split()
            if len(fields) >= 2 and fields[0] == "UID_MIN":
                return int(fields[1])
    except (OSError, ValueError):
        pass
    return 1000


def account_icon(account: pwd.struct_passwd) -> str:
    candidates: list[Path] = []

    account_file = Path("/var/lib/AccountsService/users") / account.pw_name
    try:
        for line in account_file.read_text().splitlines():
            if line.startswith("Icon="):
                candidates.append(Path(line.split("=", 1)[1]).expanduser())
    except OSError:
        pass

    candidates.extend([
        Path("/var/lib/AccountsService/icons") / account.pw_name,
        Path(account.pw_dir) / ".face",
        Path(account.pw_dir) / ".face.icon",
        Path("/usr/share/pixmaps/faces") / f"{account.pw_name}.png",
    ])

    for candidate in candidates:
        try:
            if candidate.is_file() and os.access(candidate, os.R_OK):
                return candidate.resolve().as_uri()
        except OSError:
            continue
    return ""


def main() -> None:
    minimum = uid_min()
    current = os.environ.get("USER", "")
    users = []

    for account in pwd.getpwall():
        if account.pw_uid < minimum or account.pw_uid >= 65534:
            continue
        if account.pw_shell in BLOCKED_SHELLS:
            continue

        full_name = account.pw_gecos.split(",", 1)[0].strip()
        users.append({
            "username": account.pw_name,
            "name": full_name or account.pw_name,
            "icon": account_icon(account),
            "current": account.pw_name == current,
        })

    users.sort(key=lambda user: (not user["current"], user["name"].casefold()))
    print(json.dumps({"users": users}))


if __name__ == "__main__":
    main()
