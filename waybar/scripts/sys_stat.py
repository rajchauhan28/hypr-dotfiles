#!/usr/bin/env python3
"""
sys_stats.py
- Emits JSON with CPU/RAM/Temp icons and percentages for Waybar.
- On --popup opens a webview popup with small live graphs.
Requirements: python3-psutil
"""

import sys
import json
import psutil
import subprocess
import os
import os

def get_cpu_temp():
    """Gets CPU temperature."""
    try:
        # Note: sensor names can vary. 'coretemp' and 'k10temp' are common.
        # You might need to adjust this for your specific hardware.
        temps = psutil.sensors_temperatures()
        if not temps:
            return None

        if 'coretemp' in temps:
            return temps['coretemp'][0].current
        if 'k10temp' in temps:
            return temps['k10temp'][0].current
        
        # Fallback to the first available sensor
        for name in temps:
            if len(temps[name]) > 0:
                return temps[name][0].current

    except (AttributeError, KeyError):
        pass
    return None

def emit_json():
    """Emits JSON for Waybar."""
    cpu_percent = psutil.cpu_percent()
    ram_percent = psutil.virtual_memory().percent
    temp = get_cpu_temp()

    text = f" {cpu_percent:.0f}% |  {ram_percent:.0f}%"
    tooltip = f"CPU Usage: {cpu_percent:.0f}%\nRAM Usage: {ram_percent:.0f}%"

    if temp is not None:
        text += f" |  {temp:.0f}°C"
        tooltip += f"\nCPU Temp: {temp:.0f}°C"

<<<<<<< HEAD
# Popup with live graphs
class LivePopup(Gtk.Window):
    def __init__(self):
        super().__init__(title="System Stats")
        self.set_default_size(320, 160)
        self.set_decorated(False)
        self.set_border_width(8)
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.darea = Gtk.DrawingArea()
        self.darea.set_size_request(300, 120)
        vbox.pack_start(self.darea, True, True, 0)
        self.labels = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.cpu_label = Gtk.Label(label="")
        self.mem_label = Gtk.Label(label="")
        self.temp_label = Gtk.Label(label="")
        self.labels.pack_start(self.cpu_label, True, True, 0)
        self.labels.pack_start(self.mem_label, True, True, 0)
        self.labels.pack_start(self.temp_label, True, True, 0)
        vbox.pack_start(self.labels, False, False, 0)
        self.add(vbox)
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
        self.cpu_label.set_text(f"CPU: {int(cpu)}%")
        self.mem_label.set_text(f"RAM: {int(mem)}%")
        self.temp_label.set_text(f"TEMP: {temp}°C")
        self.darea.queue_draw()
        return True

    def on_draw(self, widget, ctx):
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()
        ctx.set_source_rgba(0.05,0.06,0.07,0.9)
        ctx.rectangle(0,0,w,h)
        ctx.fill()
        def draw_series(series, y_offset, color):
            n = len(series)
            if n < 2:
                return
            maxv = max(max(series), 100)
            step = w / max(1, n-1)
            ctx.set_line_width(2.0)
            ctx.set_source_rgba(*color)
            for i, val in enumerate(series):
                x = i * step
                y = h - (val / maxv) * h
                if i == 0:
                    ctx.move_to(x,y)
                else:
                    ctx.line_to(x,y)
            ctx.stroke()
        draw_series(self.data["cpu"], 0, (0.9,0.4,0.4,1.0))
        draw_series(self.data["mem"], 0, (0.4,0.6,0.9,1.0))
=======
    css_class = "normal"
    if ram_percent > 90 or cpu_percent > 90 or (temp is not None and temp > 85):
        css_class = "critical"
    elif ram_percent > 80 or cpu_percent > 80 or (temp is not None and temp > 70):
        css_class = "warning"

    print(json.dumps({
        'text': text,
        'tooltip': tooltip,
        'class': css_class
    }))
>>>>>>> 3216cf4 (updates waybar ui and tools)

def popup():
    env = os.environ.copy()
    env["DISPLAY"] = ":0"
    env["PATH"] = f"{env["PATH"]}:/home/reign/.local/bin"
    subprocess.Popen(["/home/reign/.config/waybar/scripts/webview_plot.py"], env=env)

if __name__ == "__main__":
    # Initialize cpu_percent before the loop
    psutil.cpu_percent()

    if "--popup" in sys.argv:
        popup()
    else:
        emit_json()

