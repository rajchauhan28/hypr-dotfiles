#!/usr/bin/env python3
import sys
import gi
import os
import math
import datetime

gi.require_version("Gtk", "4.0")
# gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, GLib, Gdk #, Gtk4LayerShell

class ClockPopup(Gtk.Application):
    def __init__(self, mode):
        super().__init__(application_id="org.waybar.clock_popup")
        self.mode = mode
        self.connect("activate", self.on_activate)

    def on_activate(self, app):
        try:
            win = Gtk.ApplicationWindow(application=app)
            win.set_title("Clock & Calendar")
            
            # Close on focus loss
            def on_focus_change(widget, param):
                if win.get_visible() and not win.is_active():
                    win.close()
            
            # win.connect("notify::is-active", on_focus_change)
            
            # Close on Escape key
            controller = Gtk.EventControllerKey()
            def on_key_pressed(controller, keyval, keycode, state):
                if keyval == Gdk.KEY_Escape:
                    win.close()
                    return True
                return False
            controller.connect("key-pressed", on_key_pressed)
            win.add_controller(controller)

            win.set_decorated(False)
            win.set_resizable(False)
            
            # Load Pywal colors if available
            self.load_css()

            main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            main_box.set_margin_start(20)
            main_box.set_margin_end(20)
            main_box.set_margin_top(20)
            main_box.set_margin_bottom(20)

            if self.mode == "calendar":
                self.create_calendar(main_box)
            else:
                self.create_clock(main_box)

            win.set_child(main_box)
            win.present()
        except Exception as e:
            print(f"Error in on_activate: {e}")
            import traceback
            traceback.print_exc()

    def load_css(self):
        css_path = os.path.expanduser("~/.cache/wal/colors.css")
        provider = Gtk.CssProvider()
        if os.path.exists(css_path):
            provider.load_from_path(css_path)
        else:
            # Fallback CSS
            css = b"""
            window { background-color: #282a36; color: #f8f8f2; }
            label { color: #f8f8f2; }
            calendar { background-color: #282a36; color: #f8f8f2; }
            """
            provider.load_from_data(css)
            
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def create_calendar(self, box):
        cal = Gtk.Calendar()
        cal.set_show_day_names(True)
        cal.set_show_heading(True)
        cal.set_show_week_numbers(False)
        box.append(cal)

    def create_clock(self, box):
        # Drawing Area for Analog Clock
        self.drawing_area = Gtk.DrawingArea()
        self.drawing_area.set_content_width(200)
        self.drawing_area.set_content_height(200)
        self.drawing_area.set_draw_func(self.draw_clock)
        box.append(self.drawing_area)

        # Digital Time Label
        self.time_label = Gtk.Label()
        self.time_label.set_markup('<span font="24" weight="bold">--:--:--</span>')
        box.append(self.time_label)

        # Update timer
        GLib.timeout_add(1000, self.update_time)
        self.update_time()

    def update_time(self):
        now = datetime.datetime.now()
        self.time_label.set_markup(f'<span font="24" weight="bold">{now.strftime("%H:%M:%S")}</span>')
        self.drawing_area.queue_draw()
        return True

    def draw_clock(self, area, cr, width, height):
        center_x = width / 2
        center_y = height / 2
        radius = min(width, height) / 2 - 5

        # Face
        cr.set_source_rgb(0.2, 0.2, 0.2) # Dark gray
        cr.arc(center_x, center_y, radius, 0, 2 * math.pi)
        cr.fill()
        
        cr.set_source_rgb(0.7, 0.7, 0.7) # Light gray border
        cr.set_line_width(2)
        cr.arc(center_x, center_y, radius, 0, 2 * math.pi)
        cr.stroke()

        now = datetime.datetime.now()
        sec = now.second
        minute = now.minute
        hour = now.hour % 12

        # Hands
        # Hour
        cr.set_source_rgb(1.0, 0.4, 0.7) # Pinkish
        cr.set_line_width(6)
        angle = (hour + minute / 60) * (math.pi / 6) - (math.pi / 2)
        cr.move_to(center_x, center_y)
        cr.line_to(center_x + math.cos(angle) * radius * 0.5,
                   center_y + math.sin(angle) * radius * 0.5)
        cr.stroke()

        # Minute
        cr.set_source_rgb(0.5, 0.9, 1.0) # Cyan
        cr.set_line_width(4)
        angle = (minute + sec / 60) * (math.pi / 30) - (math.pi / 2)
        cr.move_to(center_x, center_y)
        cr.line_to(center_x + math.cos(angle) * radius * 0.7,
                   center_y + math.sin(angle) * radius * 0.7)
        cr.stroke()

        # Second
        cr.set_source_rgb(1.0, 0.3, 0.3) # Red
        cr.set_line_width(2)
        angle = sec * (math.pi / 30) - (math.pi / 2)
        cr.move_to(center_x, center_y)
        cr.line_to(center_x + math.cos(angle) * radius * 0.85,
                   center_y + math.sin(angle) * radius * 0.85)
        cr.stroke()
        
        # Center dot
        cr.set_source_rgb(1, 1, 1)
        cr.arc(center_x, center_y, 4, 0, 2 * math.pi)
        cr.fill()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        mode = sys.argv[1]
    else:
        mode = "clock"
    
    try:
        with open("/tmp/waybar_calendar_time_mode", "r") as f:
            file_mode = f.read().strip()
            if file_mode == "date":
                mode = "calendar"
            else:
                mode = "clock"
    except FileNotFoundError:
        pass

    app = ClockPopup(mode)
    app.run(sys.argv)