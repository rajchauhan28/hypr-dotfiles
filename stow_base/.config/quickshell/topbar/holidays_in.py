#!/usr/bin/env python3
"""Indian holidays for a given year, as JSON {"YYYY-MM-DD": "Name"}.

Uses the `holidays` package when it is importable, which covers the lunar
festivals (Diwali, Holi, Eid, …) whose dates shift every year. Without it we
fall back to the fixed-date national holidays only — those are the ones that
can be stated with certainty from a formula, and inventing dates for the
movable festivals would be worse than omitting them.

Install for full coverage:  pipx install holidays  (or python-holidays)
"""
import json
import os
import sys

# Fixed-date holidays observed nationally. Movable festivals are deliberately
# absent — see the module docstring.
FIXED = {
    (1, 26): "Republic Day",
    (4, 14): "Ambedkar Jayanti",
    (5, 1): "Labour Day",
    (8, 15): "Independence Day",
    (10, 2): "Gandhi Jayanti",
    (12, 25): "Christmas",
}


def _add_pipx_venv_to_path():
    """pipx installs into an isolated venv, so the system interpreter cannot
    import the library without help. Find that venv's site-packages and put it
    on sys.path. Harmless if pipx or the package is absent."""
    import glob
    for sp in sorted(glob.glob(os.path.expanduser(
            "~/.local/share/pipx/venvs/holidays/lib/python*/site-packages"))):
        if sp not in sys.path:
            sys.path.append(sp)


def from_package(year):
    try:
        import holidays as _h
    except ImportError:
        _add_pipx_venv_to_path()
        try:
            import holidays as _h
        except ImportError:
            return None
    try:
        out = {}
        for day, name in _h.India(years=year).items():
            out[day.strftime("%Y-%m-%d")] = name
        return out
    except Exception:
        return None


def fallback(year):
    return {f"{year}-{m:02d}-{d:02d}": name for (m, d), name in FIXED.items()}


def main():
    try:
        year = int(sys.argv[1])
    except (IndexError, ValueError):
        import datetime
        year = datetime.date.today().year

    data = from_package(year)
    complete = data is not None
    if data is None:
        data = fallback(year)

    print(json.dumps({"year": year, "complete": complete, "days": data}))


if __name__ == "__main__":
    main()
