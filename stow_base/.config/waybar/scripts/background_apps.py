#!/usr/bin/env python3
"""
background_apps.py
- Waybar custom module. Emits JSON with an "icon" and "text" and "tooltip"
- On "--popup" opens a GTK popup with running background apps and actions.
"""

import sys, json, subprocess
import gi
gi.require_version('Gtk', '3.0')  # or '4.0' if you want GTK4
from gi.repository import Gtk, GLib


CANDIDATES = [
    ("firefox", "", "Firefox"),
    ("discord", "", "Discord"),
    ("slack", "", "Slack"),
    ("mpv", "", "mpv"),
    ("spotify", "", "Spotify"),
    ("thunderbird", "", "Thunderbird"),
    ("waybar", "", "Waybar"),
]

def get_running():
    # Uses pgrep for simplicity; modify to match how you identify background services.
    running = []
    for proc, icon, name in CANDIDATES:
        try:
            subprocess.check_output(["pgrep", "-x", proc])
            running.append((proc, icon, name))
        except subprocess.CalledProcessError:
            pass
    return running

def emit_json():
    running = get_running()
    icons = " ".join([i for _, i, _ in running])
    tooltip = "\n".join([n for _,_,n in running]) if running else "No known background apps running."
    out = {"text": icons, "tooltip": tooltip, "class": "custom-background-apps"}
    print(json.dumps(out))
    sys.stdout.flush()

def popup_show():
    running = get_running()
    win = Gtk.Window.new(Gtk.WindowType.POPUP)
    win.set_decorated(False)
    win.get_style_context().add_class("popup-window")
    box = Gtk.Box.new(Gtk.Orientation.VERTICAL, 8)
    header = Gtk.Label(label="Background Apps")
    header.set_markup("<b>Background Apps</b>")
    box.pack_start(header, False, False, 0)
    if not running:
        box.pack_start(Gtk.Label(label="No known background apps running."), False, False, 0)
    else:
        for proc, icon, name in running:
            row = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 8)
            lbl_icon = Gtk.Label(label=icon)
            lbl_name = Gtk.Label(label=name)
            btn_focus = Gtk.Button(label="Focus")
            def make_cb(p):
                def cb(btn):
                    # try to open or focus app using wmctrl; best-effort
                    subprocess.Popen(["hyprctl", "dispatch", f"focuswindow class:{p}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    win.destroy()
                return cb
            btn_focus.connect("clicked", make_cb(proc))
            row.pack_start(lbl_icon, False, False, 4)
            row.pack_start(lbl_name, True, True, 4)
            row.pack_start(btn_focus, False, False, 4)
            box.pack_start(row, False, False, 0)
    win.add(box)
    win.show_all()
    GLib.timeout_add_seconds(10, win.destroy)
    Gtk.main()

if __name__ == "__main__":
    if "--popup" in sys.argv:
        popup_show()
    else:
        emit_json()

