#!/usr/bin/env python3
"""
sys_stats.py
- Emits JSON with CPU/RAM/Temp icons and percentages for Waybar.
- On --popup opens a GTK popup with small live graphs (updates every 800ms).
Requirements: python3-psutil, PyGObject
"""

import sys, json, psutil, time
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GLib, Gdk, GdkPixbuf, cairo

def get_stats():
    cpu = psutil.cpu_percent(interval=None)
    mem = psutil.virtual_memory().percent
    temps = psutil.sensors_temperatures() if hasattr(psutil, "sensors_temperatures") else {}
    cpu_temp = 0
    # try a common sensor key
    for key, val in temps.items():
        if val:
            cpu_temp = int(val[0].current)
            break
    return cpu, mem, cpu_temp

def emit_json():
    cpu, mem, temp = get_stats()
    text = f" {int(cpu)}%   {int(mem)}%   {temp}°C"
    tooltip = f"CPU {cpu}%\nRAM {mem}%\nTemp {temp}°C"

    css_class = 'normal' 
    if cpu > 90 or mem > 90 or temp > 80:
        css_class = 'critical'
    elif cpu > 70 or mem > 70 or temp > 60:
        css_class = 'warning'

    out = {"text": text, "tooltip": tooltip, "class": css_class}
    print(json.dumps(out))
    sys.stdout.flush()

# Popup with live graphs
class LivePopup(Gtk.Window):
    def __init__(self):
        super().__init__(title="System Stats")
        self.set_default_size(320, 180)
        self.set_decorated(False)
        self.set_border_width(8)
        self.darea = Gtk.DrawingArea()
        self.add(self.darea)
        self.show_all()
        self.data = {"cpu": [], "mem": []}
        self.darea.connect("draw", self.on_draw)
        GLib.timeout_add(800, self.update_stats)

    def update_stats(self):
        cpu, mem, temp = get_stats()
        self.data["cpu"].append(cpu)
        self.data["mem"].append(mem)
        if len(self.data["cpu"]) > 100:
            self.data["cpu"].pop(0)
            self.data["mem"].pop(0)
        self.darea.queue_draw()
        return True

    def on_draw(self, widget, ctx):
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()

        # Background
        ctx.set_source_rgba(0.05, 0.06, 0.07, 0.9)
        ctx.rectangle(0, 0, w, h)
        ctx.fill()

        # Grid
        ctx.set_source_rgba(0.2, 0.2, 0.2, 0.5)
        ctx.set_line_width(0.5)
        for i in range(1, 5):
            y = i * h / 5
            ctx.move_to(0, y)
            ctx.line_to(w, y)
        for i in range(1, 10):
            x = i * w / 10
            ctx.move_to(x, 0)
            ctx.line_to(x, h)
        ctx.stroke()

        def draw_series(series, color, fill_color):
            n = len(series)
            if n < 2:
                return
            maxv = max(max(series), 100)
            step = w / max(1, n - 1)

            # Fill
            ctx.set_source_rgba(*fill_color)
            ctx.move_to(0, h)
            for i, val in enumerate(series):
                x = i * step
                y = h - (val / maxv) * h
                ctx.line_to(x, y)
            ctx.line_to(w, h)
            ctx.close_path()
            ctx.fill()

            # Line
            ctx.set_line_width(2.0)
            ctx.set_source_rgba(*color)
            for i, val in enumerate(series):
                x = i * step
                y = h - (val / maxv) * h
                if i == 0:
                    ctx.move_to(x, y)
                else:
                    ctx.line_to(x, y)
            ctx.stroke()

        # Draw graphs
        draw_series(self.data["cpu"], (0, 1, 1, 1), (0, 1, 1, 0.2)) # Cyan
        draw_series(self.data["mem"], (1, 0, 1, 1), (1, 0, 1, 0.2)) # Magenta

        # Legend
        ctx.select_font_face("monospace", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
        ctx.set_font_size(12)
        
        # CPU Legend
        ctx.set_source_rgba(0, 1, 1, 1)
        ctx.rectangle(10, 10, 10, 10)
        ctx.fill()
        ctx.move_to(25, 20)
        ctx.show_text(f"CPU: {int(self.data['cpu'][-1])}%")

        # RAM Legend
        ctx.set_source_rgba(1, 0, 1, 1)
        ctx.rectangle(10, 30, 10, 10)
        ctx.fill()
        ctx.move_to(25, 40)
        ctx.show_text(f"RAM: {int(self.data['mem'][-1])}%")

def popup():
    win = LivePopup()
    Gtk.main()

if __name__ == "__main__":
    if "--popup" in sys.argv:
        popup()
    else:
        emit_json()