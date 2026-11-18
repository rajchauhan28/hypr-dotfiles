#!/usr/bin/env python3
"""Health checks for the Settings app's Health page.

Prints one JSON object:
  {"checks": [{"group", "title", "status", "detail", "fix"?}]}
status is "ok", "info", "warn" or "fail". A fix is
  {"label": str, "cmd": [argv...]}
which the page runs detached when its button is clicked. Fixes only start,
restart or rebuild things; nothing here deletes files.

Every check is read-only and time-boxed: the page runs this on open and on
Refresh, and a wedged helper must not hang it.
"""
import glob
import json
import os
import re
import shutil
import subprocess

HOME = os.path.expanduser("~")
QS_LOCK = os.path.join(HOME, ".config/quickshell/lock")
GLASS_SO = os.path.join(HOME, ".local/lib/hyprland/hyprglass.so")
SETTINGS = os.path.join(HOME, ".config/quickshell/settings.json")

checks = []


def add(group, title, status, detail, fix=None):
    c = {"group": group, "title": title, "status": status, "detail": detail}
    if fix:
        c["fix"] = fix
    checks.append(c)


def run(argv, timeout=5):
    """(exit code, stdout) -- never raises; a missing tool is exit 127."""
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout
    except FileNotFoundError:
        return 127, ""
    except subprocess.TimeoutExpired:
        return 124, ""


def in_terminal(script):
    """A fix that shows its output and waits for Enter before closing."""
    return ["ghostty", "-e", "bash", "-c",
            script + '; echo; read -rp "Press Enter to close."']


# ---- Hyprland ---------------------------------------------------------------
def hyprland():
    code, out = run(["hyprctl", "configerrors"])
    if code != 0:
        add("Hyprland", "Config", "warn", "hyprctl did not answer.")
        return
    errs = [l for l in out.splitlines() if l.strip()]
    if errs:
        add("Hyprland", "Config", "fail", f"{len(errs)} error(s): {errs[0][:160]}")
    else:
        add("Hyprland", "Config", "ok", "hyprland.lua loads with no errors.")


# ---- Quickshell vs Qt -------------------------------------------------------
def quickshell_qt():
    qs = shutil.which("qs")
    if not qs:
        add("Quickshell", "Qt build match", "warn", "qs is not on PATH.")
        return
    # The Qt version qs was compiled against is baked into the binary as a
    # plain string (QT_VERSION_STR) -- the value qs itself compares at launch
    # when it logs "was built against Qt X but the system has updated to Y".
    built = None
    try:
        data = open(os.path.realpath(qs), "rb").read()
        m = re.search(rb"\x00(6\.\d+\.\d+)\x00", data)
        built = m.group(1).decode() if m else None
    except OSError:
        pass
    code, out = run(["pacman", "-Q", "qt6-base"])
    parts = out.split()
    system = parts[1].split("-")[0] if code == 0 and len(parts) > 1 else None
    if not built or not system:
        add("Quickshell", "Qt build match", "info", "Could not read the Qt versions.")
        return
    if built == system:
        add("Quickshell", "Qt build match", "ok", f"Built against Qt {built}, the installed version.")
        return
    _, owner = run(["pacman", "-Qoq", os.path.realpath(qs)])
    pkg = owner.strip() or "the quickshell package"
    add("Quickshell", "Qt build match", "warn",
        f"{pkg} was built against Qt {built}, but Qt {system} is installed. "
        "Quickshell may crash, and a crash while locked leaves a dead lock screen. "
        f"Update {pkg} once a rebuild for Qt {system} is available.")


# ---- Lock daemon ------------------------------------------------------------
def lock_daemon():
    restart = {"label": "Restart",
               "cmd": ["sh", "-c", 'timeout 3 qs kill -p "$1" >/dev/null 2>&1; exec qs -d -p "$1"',
                       "sh", QS_LOCK]}
    code, out = run(["qs", "ipc", "-p", QS_LOCK, "show"], timeout=3)
    if code == 0 and "target session" in out:
        add("Quickshell", "Lock screen daemon", "ok", "Running and answering; Super+L locks instantly.")
    elif code == 124:
        add("Quickshell", "Lock screen daemon", "fail",
            "Running but not answering (wedged). lock.sh falls back to a slow cold start.", restart)
    else:
        add("Quickshell", "Lock screen daemon", "warn",
            "Not running. Super+L still works, but cold-starts the lock (slower).", restart)


# ---- Glass plugin -----------------------------------------------------------
def glass():
    mode = "dark"
    try:
        t = json.load(open(SETTINGS)).get("theme") or {}
        if t.get("mode") in ("light", "glass"):
            mode = t["mode"]
    except (OSError, ValueError, AttributeError):
        pass
    code, out = run(["hyprctl", "-j", "version"])
    try:
        running = json.loads(out)["tag"].lstrip("v") if code == 0 else None
    except (ValueError, KeyError):
        running = None
    try:
        stamp = open(GLASS_SO + ".version").read().strip()
    except OSError:
        stamp = None
    _, plugins = run(["hyprctl", "plugin", "list"])
    loaded = "hyprglass" in plugins

    rebuild = {"label": "Rebuild",
               "cmd": in_terminal('"$HOME/.config/hypr/build-hyprglass.sh" && hyprctl reload >/dev/null && echo "Done."')}
    built = os.path.exists(GLASS_SO)
    fresh = built and stamp is not None and stamp == running
    built_for = "an unknown Hyprland version" if stamp is None else f"Hyprland {stamp}"
    if mode != "glass":
        if loaded or fresh or not built:
            add("Hyprland", "Glass plugin", "ok", f"Not used by the {mode} theme.")
        else:
            add("Hyprland", "Glass plugin", "info",
                f"Not used by the {mode} theme. The build on disk is for {built_for}; "
                "rebuild it before switching to glass.", rebuild)
        return
    if loaded:
        add("Hyprland", "Glass plugin", "ok", f"Loaded (built for Hyprland {stamp or running}).")
    elif not built:
        add("Hyprland", "Glass plugin", "warn", "The glass theme is on but hyprglass is not built.", rebuild)
    elif not fresh:
        add("Hyprland", "Glass plugin", "warn",
            f"Built for {built_for}, running {running}: not loaded, so glass shows as "
            "plain translucent dark.", rebuild)
    elif os.path.exists(os.path.join(HOME, ".cache/hyprglass.loading")):
        add("Hyprland", "Glass plugin", "fail",
            "Skipped by the crash guard: Hyprland died while loading it. Rebuild, then reload.", rebuild)
    else:
        add("Hyprland", "Glass plugin", "warn", "Up to date but not loaded yet.",
            {"label": "Reload Hyprland", "cmd": ["hyprctl", "reload"]})


# ---- Background services ----------------------------------------------------
def services():
    # (label, systemd unit, process hyprland.lua starts directly when the
    #  unit is not enabled -- or None)
    wanted = [
        ("Session target", "hyprland-session.target", None),
        ("Idle / screen-off (hypridle)", "hypridle.service", "hypridle"),
        ("Scratchpads (pyprland)", "pyprland.service", "pypr"),
        ("Clipboard history: text", "cliphist-text.service", None),
        ("Clipboard history: images", "cliphist-image.service", None),
        ("Wallpaper daemon (walllust)", "walllust-daemon.service", None),
    ]
    for label, unit, proc in wanted:
        active = run(["systemctl", "--user", "is-active", unit])[1].strip()
        if active == "active":
            add("Services", label, "ok", f"{unit} is running.")
            continue
        if proc and run(["pgrep", "-x", proc])[0] == 0:
            add("Services", label, "ok", f"Running ({proc}, started by hyprland.lua).")
            continue
        enabled = run(["systemctl", "--user", "is-enabled", unit])[1].strip()
        if enabled in ("", "not-found") and active in ("", "inactive", "unknown"):
            add("Services", label, "info", f"{unit} is not installed.")
            continue
        if proc:
            fix = {"label": "Start", "cmd": ["setsid", "-f", proc]}
        else:
            fix = {"label": "Start", "cmd": ["systemctl", "--user", "restart", unit]}
        add("Services", label, "fail" if active == "failed" else "warn",
            f"{unit} is {active or 'not running'} ({enabled or 'not enabled'}).", fix)


# ---- Dotfile links ----------------------------------------------------------
def links():
    qs_real = os.path.realpath(os.path.join(HOME, ".config/quickshell"))
    stow_base = os.path.dirname(os.path.dirname(qs_real))
    if os.path.basename(stow_base) != "stow_base":
        add("Dotfiles", "Links", "info", "~/.config/quickshell is not a stow link; skipped.")
        return
    repo = os.path.dirname(stow_base)

    # Links into the repo whose target is gone (a file renamed or deleted
    # there that is still linked here). Reported only -- deleting is left to
    # the user.
    dangling = []
    for root in (os.path.join(HOME, ".config"), os.path.join(HOME, ".local/bin"),
                 os.path.join(HOME, ".local/share/applications")):
        for path in glob.glob(os.path.join(root, "*")) + glob.glob(os.path.join(root, "*/*")):
            if os.path.islink(path) and not os.path.exists(path):
                target = os.readlink(path)
                if repo in os.path.realpath(path) or "hypr-dotfiles" in target:
                    dangling.append(path.replace(HOME, "~", 1))
    if dangling:
        add("Dotfiles", "Broken links", "warn",
            f"{len(dangling)} link(s) into the repo point at nothing: " + ", ".join(dangling[:4])
            + (" …" if len(dangling) > 4 else ""))
    else:
        add("Dotfiles", "Broken links", "ok", "No dangling links into the repo.")

    # Repo files whose home copy is no longer the link: an app saved over the
    # symlink (mimeapps.list does this on every default-app change), so the
    # repo version silently stopped applying.
    drifted = []
    candidates = glob.glob(os.path.join(stow_base, ".config", "*")) + \
        [p for p in glob.glob(os.path.join(stow_base, ".*")) if os.path.isfile(p)]
    for src in candidates:
        rel = os.path.relpath(src, stow_base)
        dst = os.path.join(HOME, rel)
        if os.path.islink(dst) or not os.path.exists(dst):
            continue
        if os.path.isfile(dst) and os.path.isfile(src):
            drifted.append("~/" + rel)
    if drifted:
        add("Dotfiles", "Replaced links", "info",
            "Real files where the repo expects a link, so the repo copy is not in use: "
            + ", ".join(drifted) + ". Usually an app saving over the link; "
            "copy the file into the repo if you want the change kept.")
    else:
        add("Dotfiles", "Replaced links", "ok", "Every repo file is still linked in place.")


for check in (hyprland, quickshell_qt, lock_daemon, glass, services, links):
    try:
        check()
    except Exception as e:  # one broken check must not blank the page
        add("Health", check.__name__, "info", f"Check failed to run: {e}")

print(json.dumps({"checks": checks}))
