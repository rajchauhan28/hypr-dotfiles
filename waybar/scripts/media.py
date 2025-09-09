#!/usr/bin/env python3
import subprocess
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, Gdk
import sys

class MediaPopup(Gtk.Window):
    def __init__(self, text):
        super().__init__(title="Now Playing")
        self.set_decorated(False)
        self.set_default_size(280, 100)
        self.set_border_width(12)
        self.override_background_color(Gtk.StateFlags.NORMAL, Gdk.RGBA(0.11, 0.12, 0.16, 0.95))

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        label = Gtk.Label(label=text)
        label.set_xalign(0)
        label.set_justify(Gtk.Justification.LEFT)
        label.set_markup(f"<span font='12' foreground='#cdd6f4'>{text}</span>")
        box.pack_start(label, True, True, 0)

        self.add(box)

def get_media_info():
    try:
        output = subprocess.check_output(
            ["playerctl", "metadata", "--format", "{{artist}} - {{title}}"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()
        if not output:
            return "No media playing"
        return output
    except:
        return "No players found"

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "popup":
        info = get_media_info()
        win = MediaPopup(info)
        win.show_all()
        Gtk.main()
    else:
        print(get_media_info())

