import sys
import gi
import json
import os
import math
import cairo

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, GLib, Gdk

class SysStatPopup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.waybar.sys_stat_popup")
        self.connect("activate", self.on_activate)
        
        self.cpu_data = [0.0] * 40
        self.ram_data = [0.0] * 40
        self.disk_percent = 0.0
        self.temp_value = 0.0
        self.uptime_str = "--"

    def on_activate(self, app):
        win = Gtk.ApplicationWindow(application=app)
        win.set_title("System Monitor")
        win.set_default_size(360, 480)
        
        # Close on Escape key
        controller = Gtk.EventControllerKey()
        def on_key_pressed(controller, keyval, keycode, state):
            if keyval == Gdk.KEY_Escape:
                win.close()
                return True
            return False
        controller.connect("key-pressed", on_key_pressed)
        win.add_controller(controller)

        # Basic styling
        self.load_css()

        # Main Container
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        main_box.set_margin_start(20)
        main_box.set_margin_end(20)
        main_box.set_margin_top(20)
        main_box.set_margin_bottom(20)

        # Header
        header_label = Gtk.Label(label="System Dashboard")
        header_label.set_markup('<span font="16" weight="bold">System Dashboard</span>')
        main_box.append(header_label)
        
        sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        main_box.append(sep)

        # Uptime & Temp Row
        info_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        info_box.set_homogeneous(True)
        main_box.append(info_box)

        # Uptime
        uptime_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        uptime_label = Gtk.Label(label="Uptime")
        uptime_label.add_css_class("dim-label")
        self.uptime_val_label = Gtk.Label(label="--")
        self.uptime_val_label.add_css_class("value-label")
        uptime_vbox.append(uptime_label)
        uptime_vbox.append(self.uptime_val_label)
        info_box.append(uptime_vbox)

        # Temp
        temp_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        temp_label = Gtk.Label(label="CPU Temp")
        temp_label.add_css_class("dim-label")
        self.temp_val_label = Gtk.Label(label="--")
        self.temp_val_label.add_css_class("accent-red")
        self.temp_val_label.add_css_class("value-label")
        temp_vbox.append(temp_label)
        temp_vbox.append(self.temp_val_label)
        info_box.append(temp_vbox)

        # CPU Graph Area
        cpu_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        cpu_header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        cpu_header_box.append(Gtk.Label(label="CPU Usage"))
        
        self.cpu_val_label = Gtk.Label(label="0%")
        self.cpu_val_label.set_hexpand(True)
        self.cpu_val_label.set_halign(Gtk.Align.END)
        self.cpu_val_label.add_css_class("accent-green")
        cpu_header_box.append(self.cpu_val_label)
        
        cpu_box.append(cpu_header_box)
        
        self.cpu_drawing_area = Gtk.DrawingArea()
        self.cpu_drawing_area.set_content_height(80)
        self.cpu_drawing_area.set_draw_func(self.draw_cpu_graph)
        
        # Frame for graph
        cpu_frame = Gtk.Frame()
        cpu_frame.set_child(self.cpu_drawing_area)
        cpu_box.append(cpu_frame)
        
        main_box.append(cpu_box)

        # RAM Graph Area
        ram_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        ram_header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        ram_header_box.append(Gtk.Label(label="RAM Usage"))
        
        self.ram_val_label = Gtk.Label(label="0%")
        self.ram_val_label.set_hexpand(True)
        self.ram_val_label.set_halign(Gtk.Align.END)
        self.ram_val_label.add_css_class("accent-purple")
        ram_header_box.append(self.ram_val_label)
        
        ram_box.append(ram_header_box)
        
        self.ram_drawing_area = Gtk.DrawingArea()
        self.ram_drawing_area.set_content_height(80)
        self.ram_drawing_area.set_draw_func(self.draw_ram_graph)
        
        ram_frame = Gtk.Frame()
        ram_frame.set_child(self.ram_drawing_area)
        ram_box.append(ram_frame)
        
        main_box.append(ram_box)

        # Disk Usage
        disk_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        disk_header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        disk_header_box.append(Gtk.Label(label="Disk Usage (Root)"))
        
        self.disk_val_label = Gtk.Label(label="0%")
        self.disk_val_label.set_hexpand(True)
        self.disk_val_label.set_halign(Gtk.Align.END)
        self.disk_val_label.add_css_class("accent-pink")
        disk_header_box.append(self.disk_val_label)
        
        disk_box.append(disk_header_box)
        
        self.disk_bar = Gtk.ProgressBar()
        self.disk_bar.set_fraction(0.0)
        disk_box.append(self.disk_bar)
        
        main_box.append(disk_box)

        win.set_child(main_box)
        win.present()

        # Start timer
        self.update_stats()
        GLib.timeout_add(1000, self.update_stats)

    def load_css(self):
        css = b"""
        window { background-color: #282a36; color: #f8f8f2; }
        label { color: #f8f8f2; }
        .dim-label { color: #6272a4; font-size: 12px; }
        .value-label { font-size: 16px; font-weight: bold; }
        .accent-red { color: #ff5555; }
        .accent-green { color: #50fa7b; font-weight: bold; }
        .accent-purple { color: #bd93f9; font-weight: bold; }
        .accent-pink { color: #ff79c6; font-weight: bold; }
        frame { border: 1px solid #44475a; background-color: #1e1f29; border-radius: 6px; }
        progressbar trough { min-height: 8px; border-radius: 4px; background-color: #44475a; }
        progressbar progress { min-height: 8px; border-radius: 4px; background-color: #ff79c6; }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def update_stats(self):
        try:
            with open("/tmp/sys_stats.json", "r") as f:
                data = json.load(f)
                
                cpu = data.get("cpu", 0)
                ram = data.get("ram", 0)
                disk = data.get("disk", 0)
                temp = data.get("temp", 0)
                uptime = data.get("uptime", "--")

                self.cpu_data.append(cpu)
                if len(self.cpu_data) > 40: self.cpu_data.pop(0)
                
                self.ram_data.append(ram)
                if len(self.ram_data) > 40: self.ram_data.pop(0)
                
                self.disk_percent = disk
                self.temp_value = temp
                self.uptime_str = uptime
                
                # Update Labels
                self.uptime_val_label.set_label(str(uptime))
                if temp is not None:
                    self.temp_val_label.set_label(f"{temp:.0f}°C")
                else:
                    self.temp_val_label.set_label("N/A")
                    
                self.cpu_val_label.set_label(f"{cpu:.0f}%")
                self.ram_val_label.set_label(f"{ram:.0f}%")
                self.disk_val_label.set_label(f"{disk:.0f}%")
                
                self.disk_bar.set_fraction(disk / 100.0)
                
                self.cpu_drawing_area.queue_draw()
                self.ram_drawing_area.queue_draw()

        except (FileNotFoundError, json.JSONDecodeError):
            pass
        return True

    def draw_graph(self, cr, width, height, data, color_rgb):
        # Background
        cr.set_source_rgb(0.12, 0.12, 0.16) # #1e1f29
        cr.rectangle(0, 0, width, height)
        cr.fill()
        
        if len(data) < 2: return

        step_x = width / (len(data) - 1)
        
        # Path for line
        cr.move_to(0, height - (data[0] / 100.0 * height))
        for i, val in enumerate(data):
            x = i * step_x
            y = height - (val / 100.0 * height)
            cr.line_to(x, y)
            
        cr.set_source_rgb(*color_rgb)
        cr.set_line_width(2)
        cr.stroke_preserve()
        
        # Fill gradient (simulate with solid for now, or use gradient)
        pat = cairo.LinearGradient(0, 0, 0, height)
        pat.add_color_stop_rgba(0, color_rgb[0], color_rgb[1], color_rgb[2], 0.4)
        pat.add_color_stop_rgba(1, color_rgb[0], color_rgb[1], color_rgb[2], 0.0)
        
        cr.line_to(width, height)
        cr.line_to(0, height)
        cr.close_path()
        cr.set_source(pat)
        cr.fill()

    def draw_cpu_graph(self, area, cr, width, height):
        # Dracula Green: #50fa7b -> 0.31, 0.98, 0.48
        self.draw_graph(cr, width, height, self.cpu_data, (0.31, 0.98, 0.48))

    def draw_ram_graph(self, area, cr, width, height):
        # Dracula Purple: #bd93f9 -> 0.74, 0.58, 0.98
        self.draw_graph(cr, width, height, self.ram_data, (0.74, 0.58, 0.98))

if __name__ == "__main__":
    app = SysStatPopup()
    app.run(sys.argv)
