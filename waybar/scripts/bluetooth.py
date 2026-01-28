#!/usr/bin/env python3
"""
bluetooth.py - Advanced Bluetooth Widget for Waybar
Usage:
  * bluetooth.py          # Prints JSON for Waybar
  * bluetooth.py --popup  # Opens GTK4 popup
  * bluetooth.py --toggle # Toggles Bluetooth power
"""

import sys
import json
import subprocess
import shlex
import gi
import os
import re

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, GLib, Gdk

# --- Helpers ---
def run_command(command):
    try:
        return subprocess.check_output(shlex.split(command), stderr=subprocess.DEVNULL).decode().strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""

def get_bluetooth_power():
    """Returns 'on' or 'off'."""
    output = run_command("bluetoothctl show")
    if "Powered: yes" in output:
        return "on"
    return "off"

def toggle_bluetooth():
    current = get_bluetooth_power()
    new_state = "off" if current == "on" else "on"
    run_command(f"bluetoothctl power {new_state}")

def get_paired_devices():
    """
    Returns list of dicts: {mac, name, connected, battery, type}
    """
    devices = []
    # bluetoothctl devices Paired
    output = run_command("bluetoothctl devices Paired")
    for line in output.splitlines():
        parts = line.split(" ", 2)
        if len(parts) >= 3 and parts[0] == "Device":
            mac = parts[1]
            name = parts[2]
            
            # Get details
            info = run_command(f"bluetoothctl info {mac}")
            connected = "Connected: yes" in info
            
            # Try to find battery
            battery = None
            # Look for "Battery Percentage: 0xXX (YY)"
            # output format varies. Sometimes "Battery Percentage: 95"
            batt_match = re.search(r"Battery Percentage:.*?(\d+)", info)
            if not batt_match:
                batt_match = re.search(r"Battery Percentage:\s+(\d+)", info)
                
            if batt_match:
                battery = int(batt_match.group(1))
            
            # Icon type hint (optional, simple check)
            icon_type = "default"
            if "Icon: audio-headset" in info: icon_type = "headset"
            elif "Icon: input-mouse" in info: icon_type = "mouse"
            elif "Icon: input-keyboard" in info: icon_type = "keyboard"
            elif "Icon: phone" in info: icon_type = "phone"

            devices.append({
                "mac": mac,
                "name": name,
                "connected": connected,
                "battery": battery,
                "type": icon_type
            })
    return devices

def get_icon(dev_type):
    if dev_type == "headset": return "󰋎"
    if dev_type == "mouse": return "󰍽"
    if dev_type == "keyboard": return "󰌌"
    if dev_type == "phone": return "󰏲"
    return "󰂯"

# --- Waybar Output ---
def emit_waybar_json():
    icon_only = "--icon" in sys.argv
    power = get_bluetooth_power()
    
    if power == "off":
        out = {
            "text": "󰂲", # Always icon only for off state usually, or "󰂲 Off"
            "tooltip": "Bluetooth is off. Click to enable.",
            "class": "off",
            "percentage": 0
        }
        if not icon_only: out["text"] += " Off"
    else:
        devices = get_paired_devices()
        connected_devs = [d for d in devices if d['connected']]
        
        if connected_devs:
            # Show first connected device name
            primary = connected_devs[0]
            icon = get_icon(primary['type'])
            
            # Build tooltip
            tooltip_lines = []
            for d in connected_devs:
                batt_str = f" ({d['battery']}%) " if d['battery'] is not None else ""
                tooltip_lines.append(f"{d['name']}{batt_str}")
            
            out = {
                "text": f"{icon}",
                "tooltip": "Connected:\n" + "\n".join(tooltip_lines),
                "class": "connected",
                "percentage": primary['battery'] if primary['battery'] is not None else 0
            }
            if not icon_only: out["text"] += f" {primary['name']}"
        else:
            out = {
                "text": "󰂯",
                "tooltip": "Bluetooth On - No devices connected",
                "class": "on",
                "percentage": 0
            }
            if not icon_only: out["text"] += " On"
    
    print(json.dumps(out))
    sys.stdout.flush()

# --- GTK4 Popup ---
class BluetoothPopup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.waybar.bluetooth.popup")

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_title("Bluetooth Manager")
        win.set_decorated(False)
        win.set_resizable(False)
        self.load_css()

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        main_box.set_margin_start(15)
        main_box.set_margin_end(15)
        main_box.set_margin_top(15)
        main_box.set_margin_bottom(15)

        # Header with Toggle
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        lbl = Gtk.Label()
        lbl.set_markup("<b>Bluetooth Devices</b>")
        lbl.set_hexpand(True)
        lbl.set_xalign(0)
        
        self.switch = Gtk.Switch()
        self.switch.set_active(get_bluetooth_power() == "on")
        self.switch.connect("state-set", self.on_switch_toggle)
        
        refresh_btn = Gtk.Button(icon_name="view-refresh-symbolic")
        refresh_btn.connect("clicked", self.refresh_list)

        header_box.append(lbl)
        header_box.append(self.switch)
        header_box.append(refresh_btn)
        main_box.append(header_box)
        
        # Scrolled Window for list
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_min_content_height(300)
        scrolled.set_min_content_width(300)
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        
        self.list_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        scrolled.set_child(self.list_box)
        main_box.append(scrolled)

        win.set_child(main_box)
        self.refresh_list(None)
        win.present()

    def load_css(self):
        wal_css = os.path.expanduser("~/.cache/wal/colors.css")
        if os.path.exists(wal_css):
            provider = Gtk.CssProvider()
            provider.load_from_path(wal_css)
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    def on_switch_toggle(self, switch, state):
        toggle_bluetooth()
        GLib.timeout_add(1000, lambda: self.refresh_list(None))
        return False

    def refresh_list(self, widget):
        child = self.list_box.get_first_child()
        while child:
            self.list_box.remove(child)
            child = self.list_box.get_first_child()

        if get_bluetooth_power() == "off":
            self.list_box.append(Gtk.Label(label="Bluetooth is disabled"))
            return

        devices = get_paired_devices()
        
        if not devices:
            self.list_box.append(Gtk.Label(label="No paired devices found"))
            return

        for d in devices:
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            row.set_margin_start(5)
            row.set_margin_end(5)
            
            # Label
            batt_str = f" {d['battery']}%" if d['battery'] is not None else ""
            txt = f"{d['name']}{batt_str}"
            if d['connected']:
                txt = f"<b>{txt}</b>"
            
            lbl = Gtk.Label()
            lbl.set_markup(txt)
            lbl.set_xalign(0)
            lbl.set_hexpand(True)
            
            # Connect/Disconnect Button
            btn = Gtk.Button()
            if d['connected']:
                btn.set_label("Disconnect")
                btn.add_css_class("destructive-action")
            else:
                btn.set_label("Connect")
                btn.add_css_class("suggested-action")
            
            btn.connect("clicked", self.make_conn_cb(d['mac'], d['connected']))
            
            row.append(lbl)
            row.append(btn)
            self.list_box.append(row)

    def make_conn_cb(self, mac, connected):
        def cb(btn):
            cmd = "disconnect" if connected else "connect"
            subprocess.Popen(["bluetoothctl", cmd, mac])
            # Close popup to update status? or just refresh?
            # Refreshing might take a moment for connection to establish. 
            # Let's close it, it's simpler for the user to reopen or see status on bar.
            self.quit()
        return cb

if __name__ == "__main__":
    if "--popup" in sys.argv:
        app = BluetoothPopup()
        app.run(None)
    elif "--toggle" in sys.argv:
        toggle_bluetooth()
    else:
        emit_waybar_json()
