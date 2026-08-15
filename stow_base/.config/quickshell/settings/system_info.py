#!/usr/bin/env python3
"""Return the host OS name and its best available logo file."""

import glob
import json
from pathlib import Path


def os_release() -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        for line in Path("/etc/os-release").read_text().splitlines():
            if "=" not in line or line.lstrip().startswith("#"):
                continue
            key, value = line.split("=", 1)
            values[key] = value.strip().strip('"').strip("'")
    except OSError:
        pass
    return values


def logo_path(names: list[str]) -> str:
    roots = ("/usr/share/icons", "/usr/share/pixmaps")
    extensions = ("svg", "png", "xpm")
    for name in names:
        if not name:
            continue
        for root in roots:
            for extension in extensions:
                direct = Path(root) / f"{name}.{extension}"
                if direct.is_file():
                    return direct.as_uri()
                matches = glob.glob(
                    f"{root}/**/{name}.{extension}", recursive=True
                )
                if matches:
                    return Path(matches[0]).as_uri()
    return ""


def main() -> None:
    values = os_release()
    distro_id = values.get("ID", "linux")
    logo = values.get("LOGO", distro_id)
    names = [logo, distro_id, f"{distro_id}-logo", "distributor-logo"]
    print(json.dumps({
        "name": values.get("PRETTY_NAME", values.get("NAME", "Linux")),
        "id": distro_id,
        "logoName": logo,
        "icon": logo_path(names),
    }))


if __name__ == "__main__":
    main()
