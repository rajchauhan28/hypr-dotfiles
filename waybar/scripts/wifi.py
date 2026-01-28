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

def sync_time():
    flag_file = "/tmp/.waybar_time_synced"
    if not os.path.exists(flag_file):
        try:
            # Check if NTP is already enabled
            ntp_status = subprocess.check_output(
                ["timedatectl", "show", "-p", "NTP", "--value"], 
                stderr=subprocess.DEVNULL
            ).decode().strip()
            
            if ntp_status == "no":
                # Try to enable it without asking for password
                subprocess.run(
                    ["timedatectl", "set-ntp", "true", "--no-ask-password"], 
                    stdout=subprocess.DEVNULL, 
                    stderr=subprocess.DEVNULL
                )
            
            # Create flag file to avoid repeated checks this session
            with open(flag_file, 'w') as f:
                f.write('synced')
        except Exception:
            pass

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

class PasswordDialog(Gtk.Window):
    def __init__(self, ssid, parent, callback):
        super().__init__(transient_for=parent, modal=True)
        self.ssid = ssid
        self.callback = callback
        self.set_title(f"Password for {ssid}")
        self.set_resizable(False)
        self.set_default_size(300, -1)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_start(20)
        box.set_margin_end(20)
        self.set_child(box)

        lbl = Gtk.Label(label=f"Enter password for <b>{ssid}</b>")
        lbl.set_use_markup(True)
        box.append(lbl)

        self.entry = Gtk.PasswordEntry()
        box.append(self.entry)

        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        btn_box.set_halign(Gtk.Align.CENTER)
        box.append(btn_box)

        cancel_btn = Gtk.Button(label="Cancel")
        cancel_btn.connect("clicked", lambda x: self.destroy())
        btn_box.append(cancel_btn)

        connect_btn = Gtk.Button(label="Connect")
        connect_btn.add_css_class("suggested-action")
        connect_btn.connect("clicked", self.on_connect)
        self.set_default_widget(connect_btn)
        btn_box.append(connect_btn)

    def on_connect(self, btn):
        text = self.entry.get_text()
        self.callback(text)
        self.destroy()

# --- Waybar JSON emitters ---
def emit_network_json():
    cur = current_connection()
    icon = ""
    if cur:
        sync_time()
        text = f"{icon} {cur}"
        css_class = "connected"
    else:
        flag_file = "/tmp/.waybar_time_synced"
        if os.path.exists(flag_file):
            try:
                os.remove(flag_file)
            except OSError:
                pass
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
        
        # Keep a reference to prevent garbage collection of the dialog
        self.active_dialog = None

        def get_saved_connections():
            try:
                output = run_command("nmcli -t -f NAME connection show")
                return set(line.strip() for line in output.splitlines() if line.strip())
            except:
                return set()

        def update_ui():
            child = self.network_list_box.get_first_child()
            while child:
                self.network_list_box.remove(child)
                child = self.network_list_box.get_first_child()

            nets = sorted(nmcli_list(), key=lambda x: x['signal'], reverse=True)
            saved_conns = get_saved_connections()

            if not nets:
                self.network_list_box.append(Gtk.Label(label="No networks found."))

            for n in nets:
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                name_label = Gtk.Label(label=f'{n["ssid"]} ({n["signal"]}%)')
                name_label.set_xalign(0)
                btn_label = "Disconnect" if n["active"] else "Connect"
                btn = Gtk.Button(label=btn_label)

                def make_cb(ssid, active, security):
                    def cb(widget):
                        if active:
                            subprocess.Popen(["nmcli", "connection", "down", ssid])
                            self.quit()
                        else:
                            # Heuristic: if security string indicates protection and not saved, ask pass
                            # SECURITY field usually: "WPA2" or "WPA1 WPA2" or "NONE" or "--"
                            is_secure = security and security != "--" and security.upper() != "NONE"
                            is_saved = ssid in saved_conns
                            
                            if is_secure and not is_saved:
                                def on_pass(password):
                                    if password:
                                        subprocess.Popen(["nmcli", "device", "wifi", "connect", ssid, "password", password])
                                    else:
                                        subprocess.Popen(["nmcli", "device", "wifi", "connect", ssid, "--ask"])
                                    self.active_dialog = None # Cleanup ref
                                    self.quit()

                                root = widget.get_root()
                                self.active_dialog = PasswordDialog(ssid, root, on_pass)
                                self.active_dialog.present()
                            else:
                                # Saved or Open
                                subprocess.Popen(["nmcli", "device", "wifi", "connect", ssid, "--ask"])
                                self.quit()
                    return cb

                btn.connect("clicked", make_cb(n["ssid"], n["active"], n["sec"]))

                row.append(name_label)
                row.append(btn)
                self.network_list_box.append(row)
            
            refresh_btn.set_label("Refresh")
            refresh_btn.set_sensitive(True)
            return False

        def on_refresh(widget=None):
            refresh_btn.set_label("Scanning...")
            refresh_btn.set_sensitive(False)
            # Force UI update for label change
            while GLib.MainContext.default().iteration(False):
                pass
            
            # Trigger rescan
            subprocess.Popen(["nmcli", "device", "wifi", "rescan"], stderr=subprocess.DEVNULL)
            # Wait for scan results to propagate
            GLib.timeout_add(2000, update_ui)

        refresh_btn.connect("clicked", on_refresh)
        update_ui()

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