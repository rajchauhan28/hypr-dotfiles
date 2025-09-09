#!/usr/bin/env python3
"""
wifi_bt.py - GTK4 version
- Usage:
  * wifi_bt.py --mode network    # prints JSON used by Waybar
  * wifi_bt.py --mode bluetooth  # prints JSON for BT module
  * wifi_bt.py --popup network   # opens GTK4 popup for WiFi
  * wifi_bt.py --popup bluetooth # opens GTK4 popup for Bluetooth
"""

import sys
import json
import subprocess
import shlex
import gi
import os

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, GLib, Gdk

# --- Helper functions for command-line utilities ---
def run_command(command):
    try:
        return subprocess.check_output(shlex.split(command), stderr=subprocess.DEVNULL).decode().strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""

def nmcli_list():
    """Returns a de-duplicated list of dictionaries for available WiFi networks."""
    output = run_command("nmcli -t -f SSID,SIGNAL,SECURITY,DEVICE,IN-USE device wifi list")
    networks = {}
    for line in output.splitlines():
        parts = line.split(":", 4)
        if len(parts) >= 5:
            ssid, signal, security, device, in_use = parts
            if not ssid:
                continue
            signal = int(signal) if signal else 0
            if ssid not in networks or signal > networks[ssid]["signal"]:
                networks[ssid] = {
                    "ssid": ssid,
                    "signal": signal,
                    "sec": security,
                    "device": device,
                    "active": in_use == "*"
                }
    return list(networks.values())

def current_connection():
    """Returns the name of the active WiFi connection."""
    output = run_command("nmcli -t -f NAME,TYPE,DEVICE,STATE connection show --active")
    for line in output.splitlines():
        parts = line.split(':')
        if len(parts) >= 4 and parts[1] == '802-11-wireless' and parts[3] == 'activated':
            return parts[0]
    return None

def bluetooth_list():
    """Returns a list of dictionaries for paired Bluetooth devices."""
    output = run_command("bluetoothctl devices Paired")
    devices = []
    for line in output.splitlines():
        parts = line.split(" ", 2)
        if len(parts) >= 3 and parts[0] == "Device":
            mac = parts[1]
            name = parts[2]
            info = run_command(f"bluetoothctl info {mac}")
            connected = "Connected: yes" in info
            devices.append({"mac": mac, "name": name, "connected": connected})
    return devices

# --- Waybar JSON emitters ---
def emit_network_json():
    cur = current_connection()
    icon = ""
    if cur:
        text = f"{icon} {cur}"
        css_class = "connected"
    else:
        text = f"{icon} Disconnected"
        css_class = "disconnected"
    out = {"text": text, "tooltip": "Click to see networks", "class": css_class}
    print(json.dumps(out))
    sys.stdout.flush()

def emit_bluetooth_json():
    devs = bluetooth_list()
    icon = ""
    text = "Off"
    css_class = "off"
    power_state = run_command("bluetoothctl show")
    if "Powered: yes" in power_state:
        text = "On"
        css_class = "on"
        connected_dev = next((d for d in devs if d["connected"]), None)
        if connected_dev:
            text = connected_dev['name']
            css_class = "connected"
    text = f"{icon} {text}"
    out = {"text": text, "tooltip": "Click to see devices", "class": css_class}
    print(json.dumps(out))
    sys.stdout.flush()

# --- GTK4 Popup Application ---
class Popup(Gtk.Application):
    def __init__(self, mode):
        super().__init__(application_id=f"org.example.wifi_bt_popup.{mode}")
        self.mode = mode

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_title(f"{self.mode.capitalize()} Popup")
        win.set_decorated(False)
        win.set_resizable(False)
        
        self.load_pywal_css(win)

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        main_box.set_margin_start(15)
        main_box.set_margin_end(15)
        main_box.set_margin_top(15)
        main_box.set_margin_bottom(15)

        if self.mode == "network":
            self.create_network_list(main_box)
        elif self.mode == "bluetooth":
            self.create_bluetooth_list(main_box)

        win.set_child(main_box)
        win.present()

    def load_pywal_css(self, win):
        wal_css_path = os.path.expanduser("~/.cache/wal/colors.css")
        if os.path.exists(wal_css_path):
            provider = Gtk.CssProvider()
            provider.load_from_path(wal_css_path)
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    def create_network_list(self, main_box):
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        lbl = Gtk.Label(label="<b>Available WiFi</b>")
        lbl.set_use_markup(True)
        lbl.set_xalign(0)
        refresh_btn = Gtk.Button(label="Refresh")
        
        header_box.append(lbl)
        header_box.append(refresh_btn)
        main_box.append(header_box)
        
        self.network_list_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        main_box.append(self.network_list_box)

        def update_list(widget=None):
            child = self.network_list_box.get_first_child()
            while child:
                self.network_list_box.remove(child)
                child = self.network_list_box.get_first_child()

            nets = sorted(nmcli_list(), key=lambda x: x['signal'], reverse=True)
            if not nets:
                self.network_list_box.append(Gtk.Label(label="No networks found."))

            for n in nets:
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                name_label = Gtk.Label(label=f'{n["ssid"]} ({n["signal"]}%)')
                name_label.set_xalign(0)
                btn_label = "Disconnect" if n["active"] else "Connect"
                btn = Gtk.Button(label=btn_label)

                def make_cb(ssid, active):
                    def cb(widget):
                        if active:
                            subprocess.Popen(["nmcli", "connection", "down", ssid])
                        else:
                            subprocess.Popen(["nmcli", "device", "wifi", "connect", ssid, "--ask"])
                        self.quit()
                    return cb

                btn.connect("clicked", make_cb(n["ssid"], n["active"]))

                row.append(name_label)
                row.append(btn)
                self.network_list_box.append(row)

        refresh_btn.connect("clicked", update_list)
        update_list()

    def create_bluetooth_list(self, main_box):
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        lbl = Gtk.Label(label="<b>Bluetooth Devices</b>")
        lbl.set_use_markup(True)
        lbl.set_xalign(0)
        refresh_btn = Gtk.Button(label="Refresh")
        
        header_box.append(lbl)
        header_box.append(refresh_btn)
        main_box.append(header_box)
        
        self.device_list_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        main_box.append(self.device_list_box)

        def update_list(widget=None):
            child = self.device_list_box.get_first_child()
            while child:
                self.device_list_box.remove(child)
                child = self.device_list_box.get_first_child()

            devs = bluetooth_list()
            if not devs:
                self.device_list_box.append(Gtk.Label(label="No paired devices found."))

            for d in devs:
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                name_label = Gtk.Label(label=f'{d["name"]}')
                name_label.set_xalign(0)
                btn_label = "Disconnect" if d["connected"] else "Connect"
                btn = Gtk.Button(label=btn_label)

                def make_cb(mac, connected):
                    def cb(widget):
                        cmd = "disconnect" if connected else "connect"
                        subprocess.Popen(["bluetoothctl", cmd, mac])
                        GLib.timeout_add(500, self.quit)
                    return cb

                btn.connect("clicked", make_cb(d["mac"], d["connected"]))

                row.append(name_label)
                row.append(btn)
                self.device_list_box.append(row)

        refresh_btn.connect("clicked", update_list)
        update_list()

if __name__ == "__main__":
    if "--mode" in sys.argv:
        idx = sys.argv.index("--mode")
        mode = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else "network"
        if mode == "network":
            emit_network_json()
        elif mode == "bluetooth":
            emit_bluetooth_json()
    elif "--popup" in sys.argv:
        idx = sys.argv.index("--popup")
        mode = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else "network"
        app = Popup(mode)
        app.run(None)
    else:
        emit_network_json()