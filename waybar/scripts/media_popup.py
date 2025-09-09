#!/usr/bin/env python3
"""
media_popup.py
- --mode status : prints simple JSON with currently playing track
- --popup       : opens a GTK popup with album cover and controls integrated with playerctl
Requirements: playerctl, PyGObject, python-gtk4-layer-shell
"""

import sys, json, subprocess, shlex, urllib.request
import gi
gi.require_version('Gtk', '4.0')
# Note: The GtkLayerShell library version is typically 1.0, not 4.
# If this script fails, ensure you have python-gtk4-layer-shell installed.
gi.require_version('GtkLayerShell', '4')
from gi.repository import Gtk, GLib, GdkPixbuf, GtkLayerShell

def get_playerctl_metadata():
    try:
        # Get all metadata in one go
        data = subprocess.check_output([
            "playerctl", "metadata",
            "--format",
            "{xesam:artist}\n{xesam:title}\n{mpris:artUrl}\n{mpris:length}\n{position}"
        ], text=True).strip().split('\n')
        
        status = subprocess.check_output(["playerctl", "status"], text=True).strip()
        
        if len(data) < 5: return None

        return {
            "artist": data[0],
            "title": data[1],
            "art": data[2],
            "length": int(data[3]) if data[3] else 0,
            "position": int(data[4]) if data[4] else 0,
            "status": status
        }
    except (subprocess.CalledProcessError, IndexError):
        return None

def emit_status():
    m = get_playerctl_metadata()
    if not m:
        out = {"icon": "", "text": "No player"}
    else:
        icon = "" if m["status"] == "Playing" else ""
        out = {"icon": icon, "text": f"{m['title']} - {m['artist']}", "tooltip": m['title']}
    print(json.dumps(out))
    sys.stdout.flush()

class Popup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.example.media_popup")
        self.metadata = None
        self.progress_bar = None
        self.connect("activate", self.on_activate)

    def on_activate(self, app):
        self.metadata = get_playerctl_metadata()
        
        win = Gtk.ApplicationWindow(application=app)
        win.set_decorated(False)
        
        # Layer shell configuration
        GtkLayerShell.init_for_window(win)
        GtkLayerShell.set_layer(win, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_margin(win, GtkLayerShell.Edge.TOP, 50)
        GtkLayerShell.set_margin(win, GtkLayerShell.Edge.LEFT, 10)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(8)
        box.set_margin_end(8)
        win.set_child(box)

        if not self.metadata:
            box.append(Gtk.Label(label="No media playing"))
            win.present()
            return

        # --- Main layout ---
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.append(hbox)

        # --- Album Art ---
        art_img = Gtk.Image()
        art_img.set_pixel_size(96)
        self.load_album_art(art_img, self.metadata['art'])
        hbox.append(art_img)

        # --- Metadata and Controls ---
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        hbox.append(vbox)

        lbl_title = Gtk.Label(label=f"<b>{self.metadata['title']}</b>", xalign=0)
        lbl_title.set_use_markup(True)
        vbox.append(lbl_title)

        lbl_artist = Gtk.Label(label=self.metadata['artist'], xalign=0)
        vbox.append(lbl_artist)

        # --- Progress Bar ---
        self.progress_bar = Gtk.ProgressBar()
        self.progress_bar.set_hexpand(True)
        vbox.append(self.progress_bar)
        self.update_progress() # Initial update
        GLib.timeout_add_seconds(1, self.update_progress)

        # --- Buttons ---
        controls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        controls.set_halign(Gtk.Align.CENTER)
        vbox.append(controls)
        
        btn_prev = Gtk.Button(icon_name="media-skip-backward-symbolic")
        btn_play = Gtk.Button(icon_name="media-playback-start-symbolic" if self.metadata["status"] != "Playing" else "media-playback-pause-symbolic")
        btn_next = Gtk.Button(icon_name="media-skip-forward-symbolic")
        
        btn_prev.connect("clicked", self.on_control_clicked, "previous")
        btn_play.connect("clicked", self.on_control_clicked, "play-pause")
        btn_next.connect("clicked", self.on_control_clicked, "next")
        
        controls.append(btn_prev)
        controls.append(btn_play)
        controls.append(btn_next)

        win.present()

    def load_album_art(self, image_widget, url):
        if not url: return
        try:
            if url.startswith("http"):
                with urllib.request.urlopen(url) as response:
                    data = response.read()
                    loader = GdkPixbuf.PixbufLoader.new()
                    loader.write(data)
                    loader.close()
                    pixbuf = loader.get_pixbuf()
            elif url.startswith("file://"):
                path = url[7:]
                pixbuf = GdkPixbuf.Pixbuf.new_from_file(path)
            else:
                return

            # Scale it
            scaled_pb = pixbuf.scale_simple(96, 96, GdkPixbuf.InterpType.BILINEAR)
            image_widget.set_from_pixbuf(scaled_pb)

        except Exception as e:
            print(f"Failed to load album art: {e}", file=sys.stderr)

    def on_control_clicked(self, widget, action):
        subprocess.Popen(["playerctl", action])
        # We can close the popup after a control is clicked
        self.quit()

    def update_progress(self):
        if not self.metadata or not self.progress_bar: return True
        
        try:
            # Only get position for update
            pos_str = subprocess.check_output(["playerctl", "position"], text=True).strip()
            position = float(pos_str)
            length_sec = self.metadata['length'] / 1_000_000
            
            if length_sec > 0:
                fraction = position / length_sec
                self.progress_bar.set_fraction(fraction)
            
            # Keep the timer running
            return True
        except (subprocess.CalledProcessError, ValueError):
            # Stop timer if player closes
            return False

if __name__ == "__main__":
    if "--mode" in sys.argv and "status" in sys.argv:
        emit_status()
    elif "--popup" in sys.argv:
        app = Popup()
        app.run(None)
    else:
        emit_status()