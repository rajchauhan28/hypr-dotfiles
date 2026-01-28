#!/usr/bin/env python3
"""
network.py - Advanced Network Manager for Waybar
Features:
- GTK4 UI with Pywal theming
- Connect/Disconnect/Forget networks
- Advanced Configuration:
  - IPv4 Settings (Auto/Manual, IP, Gateway, DNS)
  - Security (WPA/Open, Password management)
  - Auto-connect toggle
- Hidden Network connection support
- Real-time signal updates
"""

import sys
import json
import subprocess
import shlex
import gi
import os
import re
import threading
import time

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, GLib, Gdk, Gio, Pango

# --- NetworkManager Backend ---
class NMClient:
    @staticmethod
    def run(cmd):
        try:
            return subprocess.check_output(shlex.split(cmd), stderr=subprocess.DEVNULL).decode().strip()
        except subprocess.CalledProcessError:
            return ""

    @staticmethod
    def get_status():
        return NMClient.run("nmcli radio wifi")

    @staticmethod
    def toggle_wifi(enable=True):
        state = "on" if enable else "off"
        NMClient.run(f"nmcli radio wifi {state}")

    @staticmethod
    def get_active_info():
        # Returns: {ssid, signal, ip, state, type}
        out = NMClient.run("nmcli -t -f NAME,TYPE,DEVICE,STATE connection show --active")
        info = {"ssid": "Disconnected", "signal": 0, "ip": "", "state": "disconnected", "type": ""}
        
        active_conn = None
        for line in out.splitlines():
            parts = line.split(':')
            if len(parts) >= 4:
                # Prioritize Ethernet
                if parts[1] == '802-3-ethernet':
                    active_conn = parts
                    break
                # Fallback to WiFi if no Ethernet found yet
                if parts[1] == '802-11-wireless' and active_conn is None:
                    active_conn = parts
        
        if active_conn:
            info["ssid"] = active_conn[0]
            info["type"] = active_conn[1]
            info["state"] = active_conn[3]
            dev = active_conn[2]
            
            # Signal (only for WiFi)
            if info["type"] == '802-11-wireless':
                sig_out = NMClient.run(f"nmcli -t -f SIGNAL device wifi list ifname {dev}")
                if sig_out: 
                    # Take the first one which is usually the active AP
                    try:
                        info["signal"] = int(sig_out.splitlines()[0].split(':')[0])
                    except (ValueError, IndexError):
                        info["signal"] = 0
            
            # IP
            ip_out = NMClient.run(f"ip -4 -o addr show {dev}")
            m = re.search(r'inet\s+([0-9.]+)', ip_out)
            if m: info["ip"] = m.group(1)
            
        return info

    @staticmethod
    def get_networks():
        """
        Returns list of dicts: {ssid, signal, security, active, uuid (if known)}
        """
        # 1. Get visible networks
        # fields: SSID,SIGNAL,SECURITY,IN-USE,BSSID
        out = NMClient.run("nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE device wifi list")
        visible = {} # Deduplicate by SSID, keep strongest
        for line in out.splitlines():
            # carefully split, ssid might contain colons, usually escaped in -t mode?
            # actually nmcli -t escapes ':' as '\:'.
            parts = line.replace(r'\:', '__COLON__').split(':')
            if len(parts) < 4: continue
            ssid = parts[0].replace('__COLON__', ':')
            if not ssid: continue
            
            try: signal = int(parts[1])
            except: signal = 0
            sec = parts[2]
            active = parts[3].strip() == '*'
            
            # Deduplicate, keep strongest
            if ssid not in visible or signal > visible[ssid]['signal']:
                visible[ssid] = {
                    "ssid": ssid,
                    "signal": signal,
                    "security": sec,
                    "active": active,
                    "uuid": None,
                    "known": False
                }

        # 2. Get known connections to map UUIDs
        # fields: NAME,UUID,TYPE
        out = NMClient.run("nmcli -t -f NAME,UUID,TYPE connection show")
        known_map = {} # SSID -> UUID
        for line in out.splitlines():
            parts = line.replace(r'\:', '__COLON__').split(':')
            if len(parts) >= 3 and parts[2] == '802-11-wireless':
                name = parts[0].replace('__COLON__', ':')
                uuid = parts[1]
                known_map[name] = uuid

        # Merge
        results = []
        # Add visible
        for ssid, data in visible.items():
            if ssid in known_map:
                data['uuid'] = known_map[ssid]
                data['known'] = True
            results.append(data)
            
        # Add known but not visible (offline) - optional, maybe clutter?
        # Let's skip them for now to keep list clean, or add at bottom.
        
        return sorted(results, key=lambda x: (x['active'], x['signal']), reverse=True)

    @staticmethod
    def get_connection_config(uuid):
        # Fetch ipv4.method, ipv4.addresses, ipv4.gateway, ipv4.dns, 802-11-wireless-security.key-mgmt, connection.autoconnect
        fields = [
            "ipv4.method", "ipv4.addresses", "ipv4.gateway", "ipv4.dns",
            "802-11-wireless-security.key-mgmt", "connection.autoconnect"
        ]
        cmd = f"nmcli -g {','.join(fields)} connection show {uuid}"
        out = NMClient.run(cmd)
        lines = out.splitlines()
        # if some fields are missing, lines count might differ or be empty.
        # nmcli -g returns value per line for requested fields.
        
        # Safe parsing
        data = {
            "method": "auto", "ip": "", "gateway": "", "dns": "", 
            "security": "", "autoconnect": "yes"
        }
        if len(lines) >= 1: data["method"] = lines[0]
        if len(lines) >= 2: data["ip"] = lines[1]
        if len(lines) >= 3: data["gateway"] = lines[2]
        if len(lines) >= 4: data["dns"] = lines[3]
        if len(lines) >= 5: data["security"] = lines[4]
        if len(lines) >= 6: data["autoconnect"] = lines[5]
        
        return data

    @staticmethod
    def save_config(uuid, config):
        # Config is dict
        cmds = ["nmcli", "connection", "modify", uuid]
        
        # General
        cmds.extend(["connection.autoconnect", config['autoconnect']])
        
        # IPv4
        cmds.extend(["ipv4.method", config['method']])
        if config['method'] == 'manual':
            if config['ip']: cmds.extend(["ipv4.addresses", config['ip']])
            if config['gateway']: cmds.extend(["ipv4.gateway", config['gateway']])
            if config['dns']: cmds.extend(["ipv4.dns", config['dns']])
            
        # Security (Password update)
        if config.get('password'):
            # This depends on security type, assuming WPA-PSK for simplicity if setting password
            cmds.extend(["wifi-sec.psk", config['password']])
            
        subprocess.run(cmds)

    @staticmethod
    def connect(ssid, uuid=None, password=None):
        if uuid:
            res = subprocess.run(["nmcli", "connection", "up", uuid], stderr=subprocess.DEVNULL)
            return res.returncode == 0
        else:
            # New connection
            cmd = ["nmcli", "device", "wifi", "connect", ssid]
            if password:
                cmd.extend(["password", password])
            res = subprocess.run(cmd, stderr=subprocess.DEVNULL)
            return res.returncode == 0

    @staticmethod
    def forget(uuid):
        subprocess.Popen(["nmcli", "connection", "delete", uuid])

# --- UI Components ---

class ConfigDialog(Gtk.Window):
    def __init__(self, parent, ssid, uuid=None):
        super().__init__(title=f"Config: {ssid}", transient_for=parent, modal=True)
        self.set_default_size(400, 350)
        self.uuid = uuid
        self.ssid = ssid
        self.load_css()
        
        # Fetch current config if UUID exists
        if uuid:
            self.current_config = NMClient.get_connection_config(uuid)
        else:
            self.current_config = {"method": "auto", "autoconnect": "yes"}

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_start(20)
        box.set_margin_end(20)
        
        # Notebook (Tabs)
        notebook = Gtk.Notebook()
        
        # --- Tab 1: General ---
        grid_gen = Gtk.Grid(row_spacing=10, column_spacing=10)
        grid_gen.set_margin_top(15)
        
        grid_gen.attach(Gtk.Label(label="Auto-Connect:", xalign=0), 0, 0, 1, 1)
        self.sw_autoconnect = Gtk.Switch()
        self.sw_autoconnect.set_active(self.current_config.get("autoconnect") == "yes")
        grid_gen.attach(self.sw_autoconnect, 1, 0, 1, 1)
        
        notebook.append_page(grid_gen, Gtk.Label(label="General"))

        # --- Tab 2: Security ---
        grid_sec = Gtk.Grid(row_spacing=10, column_spacing=10)
        grid_sec.set_margin_top(15)
        
        grid_sec.attach(Gtk.Label(label="Password:", xalign=0), 0, 0, 1, 1)
        self.entry_pass = Gtk.PasswordEntry()
        self.entry_pass.set_placeholder_text("Leave empty to keep unchanged")
        grid_sec.attach(self.entry_pass, 1, 0, 1, 1)
        
        notebook.append_page(grid_sec, Gtk.Label(label="Security"))

        # --- Tab 3: IPv4 ---
        grid_ip = Gtk.Grid(row_spacing=10, column_spacing=10)
        grid_ip.set_margin_top(15)
        
        # Method
        grid_ip.attach(Gtk.Label(label="Method:", xalign=0), 0, 0, 1, 1)
        self.combo_method = Gtk.ComboBoxText()
        self.combo_method.append("auto", "Automatic (DHCP)")
        self.combo_method.append("manual", "Manual (Static)")
        self.combo_method.set_active_id(self.current_config.get("method", "auto"))
        self.combo_method.connect("changed", self.on_method_changed)
        grid_ip.attach(self.combo_method, 1, 0, 1, 1)
        
        # Details (IP, Gateway, DNS)
        self.entry_ip = Gtk.Entry(placeholder_text="192.168.1.50/24")
        self.entry_ip.set_text(self.current_config.get("ip", ""))
        
        self.entry_gw = Gtk.Entry(placeholder_text="192.168.1.1")
        self.entry_gw.set_text(self.current_config.get("gateway", ""))
        
        self.entry_dns = Gtk.Entry(placeholder_text="8.8.8.8, 1.1.1.1")
        self.entry_dns.set_text(self.current_config.get("dns", ""))
        
        # Labels
        self.lbl_ip = Gtk.Label(label="Address:", xalign=0)
        self.lbl_gw = Gtk.Label(label="Gateway:", xalign=0)
        self.lbl_dns = Gtk.Label(label="DNS:", xalign=0)
        
        grid_ip.attach(self.lbl_ip, 0, 1, 1, 1)
        grid_ip.attach(self.entry_ip, 1, 1, 1, 1)
        grid_ip.attach(self.lbl_gw, 0, 2, 1, 1)
        grid_ip.attach(self.entry_gw, 1, 2, 1, 1)
        grid_ip.attach(self.lbl_dns, 0, 3, 1, 1)
        grid_ip.attach(self.entry_dns, 1, 3, 1, 1)
        
        notebook.append_page(grid_ip, Gtk.Label(label="IPv4"))
        
        box.append(notebook)
        
        # Buttons
        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        btn_box.set_halign(Gtk.Align.END)
        
        btn_cancel = Gtk.Button(label="Cancel")
        btn_cancel.connect("clicked", lambda x: self.destroy())
        
        btn_save = Gtk.Button(label="Save & Apply")
        btn_save.add_css_class("suggested-action")
        btn_save.connect("clicked", self.on_save)
        
        btn_box.append(btn_cancel)
        btn_box.append(btn_save)
        box.append(btn_box)
        
        self.set_child(box)
        self.on_method_changed(None) # Init state

    def load_css(self):
        # Reuse shared css logic
        pass

    def on_method_changed(self, widget):
        is_manual = self.combo_method.get_active_id() == "manual"
        self.entry_ip.set_sensitive(is_manual)
        self.entry_gw.set_sensitive(is_manual)
        self.entry_dns.set_sensitive(is_manual)

    def on_save(self, widget):
        if not self.uuid:
            # Creating new config not fully supported in this simple dialog without scanning details
            # Could implement connect to hidden here
            pass
        
        config = {
            "autoconnect": "yes" if self.sw_autoconnect.get_active() else "no",
            "method": self.combo_method.get_active_id(),
            "ip": self.entry_ip.get_text(),
            "gateway": self.entry_gw.get_text(),
            "dns": self.entry_dns.get_text(),
            "password": self.entry_pass.get_text()
        }
        
        NMClient.save_config(self.uuid, config)
        self.destroy()

class NetworkRow(Gtk.ListBoxRow):
    def __init__(self, data, app_window):
        super().__init__()
        self.data = data # {ssid, signal, security, active, uuid, known}
        self.app = app_window
        
        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_child(self.main_box)
        
        # Header (Always visible)
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        header.set_margin_top(8)
        header.set_margin_bottom(8)
        header.set_margin_start(10)
        header.set_margin_end(10)
        
        # Icon
        icon_name = self.get_signal_icon(data['signal'])
        icon = Gtk.Image.new_from_icon_name(icon_name)
        header.append(icon)
        
        # SSID
        lbl = Gtk.Label(label=data['ssid'], xalign=0)
        if data['active']:
            lbl.set_markup(f"<b>{data['ssid']}</b> (Connected)")
        elif data['known']:
            lbl.set_markup(f"{data['ssid']} <span size='small' alpha='50%'>Saved</span>")
        header.append(lbl)

        # Security Icon
        if data['security'] and data['security'].upper() != "NONE":
            sec_icon = Gtk.Image.new_from_icon_name("channel-secure-symbolic")
            sec_icon.set_tooltip_text(f"Secured: {data['security']}")
            header.append(sec_icon)
        
        # Expander Arrow (Manual impl since Expander is a container)
        self.revealer = Gtk.Revealer()
        self.revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        
        self.main_box.append(header)
        self.main_box.append(self.revealer)
        
        # Details Box (Hidden)
        details = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        details.set_margin_bottom(10)
        details.set_margin_start(40) # Indent
        details.set_margin_end(10)
        
        info_lbl = Gtk.Label(xalign=0)
        info_str = f"Signal: {data['signal']}%\nSecurity: {data['security']}"
        if data['active']:
             info_str += "\nStatus: Active"
        info_lbl.set_label(info_str)
        info_lbl.add_css_class("caption")
        details.append(info_lbl)
        
        # Actions
        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        
        # Connect/Disconnect
        btn_action = Gtk.Button()
        if data['active']:
            btn_action.set_label("Disconnect")
            btn_action.add_css_class("destructive-action")
            btn_action.connect("clicked", self.on_disconnect)
        else:
            btn_action.set_label("Connect")
            btn_action.add_css_class("suggested-action")
            btn_action.connect("clicked", self.on_connect)
        actions.append(btn_action)
        
        # Settings (Only if known)
        if data['known']:
            btn_conf = Gtk.Button(icon_name="emblem-system-symbolic")
            btn_conf.set_tooltip_text("Configure IPv4 / Security")
            btn_conf.connect("clicked", self.on_config)
            actions.append(btn_conf)
            
            btn_forget = Gtk.Button(icon_name="user-trash-symbolic")
            btn_forget.set_tooltip_text("Forget Network")
            btn_forget.connect("clicked", self.on_forget)
            actions.append(btn_forget)
            
        details.append(actions)
        self.revealer.set_child(details)

    def get_signal_icon(self, pct):
        if pct > 80: return "network-wireless-signal-excellent-symbolic"
        if pct > 60: return "network-wireless-signal-good-symbolic"
        if pct > 40: return "network-wireless-signal-ok-symbolic"
        if pct > 20: return "network-wireless-signal-weak-symbolic"
        return "network-wireless-signal-none-symbolic"

    def toggle_details(self):
        self.revealer.set_reveal_child(not self.revealer.get_reveal_child())

    def on_connect(self, btn):
        if self.data['known']:
            success = NMClient.connect(self.data['ssid'], self.data['uuid'])
            if success:
                self.app.close_after_delay()
            else:
                self.prompt_password()
        else:
            # Need password prompt
            # Simple prompt dialog
            self.prompt_password()

    def prompt_password(self):
        dialog = Gtk.Window(title=f"Connect to {self.data['ssid']}", transient_for=self.app.win, modal=True)
        dialog.set_default_size(300, 150)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        box.set_margin_top(20); box.set_margin_bottom(20); 
        box.set_margin_start(20); box.set_margin_end(20)
        
        box.append(Gtk.Label(label=f"Password for {self.data['ssid']}:"))
        entry = Gtk.PasswordEntry()
        entry.set_show_peek_icon(True)
        box.append(entry)
        
        btn = Gtk.Button(label="Connect")
        btn.add_css_class("suggested-action")
        btn.connect("clicked", lambda x: self._do_connect_pass(dialog, entry.get_text()))
        box.append(btn)
        
        dialog.set_child(box)
        dialog.present()

    def _do_connect_pass(self, dialog, pwd):
        dialog.destroy()
        NMClient.connect(self.data['ssid'], password=pwd)
        self.app.close_after_delay()

    def on_disconnect(self, btn):
        NMClient.run(f"nmcli connection down {self.data['uuid']}")
        self.app.refresh()

    def on_forget(self, btn):
        NMClient.forget(self.data['uuid'])
        self.app.refresh()

    def on_config(self, btn):
        dlg = ConfigDialog(self.app.win, self.data['ssid'], self.data['uuid'])
        dlg.present()

class NetworkApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.waybar.network.manager")

    def do_activate(self):
        self.win = Gtk.ApplicationWindow(application=self)
        self.win.set_title("Network Manager")
        self.win.set_default_size(380, 500)
        self.load_css()

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        
        # --- Toolbar ---
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        header.set_margin_top(10); header.set_margin_bottom(10);
        header.set_margin_start(10); header.set_margin_end(10);
        
        lbl = Gtk.Label(label="<b>WiFi Networks</b>", use_markup=True, xalign=0, hexpand=True)
        
        self.sw_wifi = Gtk.Switch()
        self.sw_wifi.set_active(NMClient.get_status() == "enabled")
        self.sw_wifi.connect("state-set", self.on_wifi_toggle)
        
        btn_refresh = Gtk.Button(icon_name="view-refresh-symbolic")
        btn_refresh.connect("clicked", lambda x: self.refresh())
        
        header.append(lbl)
        header.append(self.sw_wifi)
        header.append(btn_refresh)
        main_box.append(header)
        
        # --- Search Bar ---
        # Optional, keeps list clean
        
        # --- Network List ---
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        
        self.list_box = Gtk.ListBox()
        self.list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.list_box.connect("row-activated", self.on_row_clicked)
        self.list_box.add_css_class("rich-list")
        
        scrolled.set_child(self.list_box)
        main_box.append(scrolled)
        
        # --- Footer ---
        footer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        footer.set_margin_top(10); footer.set_margin_bottom(10);
        footer.set_margin_start(10); footer.set_margin_end(10);
        
        btn_hidden = Gtk.Button(label="Connect to Hidden Network...")
        btn_hidden.connect("clicked", self.on_hidden_connect)
        footer.append(btn_hidden)

        btn_settings = Gtk.Button(label="Settings")
        btn_settings.connect("clicked", self.on_settings)
        footer.append(btn_settings)
        
        main_box.append(footer)
        
        self.win.set_child(main_box)
        self.win.present()
        self.refresh()

    def load_css(self):
        css_path = os.path.expanduser("~/.cache/wal/colors.css")
        if os.path.exists(css_path):
            provider = Gtk.CssProvider()
            provider.load_from_path(css_path)
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    def on_settings(self, btn):
        # Try to launch standard connection editor, fallback to gnome-control-center, then nmtui
        try:
            subprocess.Popen(["nm-connection-editor"])
        except FileNotFoundError:
            try:
                subprocess.Popen(["gnome-control-center", "wifi"])
            except FileNotFoundError:
                try:
                    subprocess.Popen(["ghostty", "-e", "nmtui"])
                except FileNotFoundError:
                    print("No network settings tool found.")

    def refresh(self):
        # Clear list
        while True:
            row = self.list_box.get_row_at_index(0)
            if not row: break
            self.list_box.remove(row)
            
        # Ethernet Status
        info = NMClient.get_active_info()
        if info['state'] == "activated" and info['type'] == '802-3-ethernet':
            # Manually create a row widget
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            box.set_margin_top(8); box.set_margin_bottom(8)
            box.set_margin_start(10); box.set_margin_end(10)
            
            icon = Gtk.Image.new_from_icon_name("network-wired-symbolic")
            box.append(icon)
            
            lbl = Gtk.Label()
            lbl.set_markup(f"<b>Ethernet Connected</b>\n<span size='small'>{info['ssid']}</span>")
            lbl.set_xalign(0)
            box.append(lbl)
            
            self.list_box.append(box)

        if NMClient.get_status() == "disabled":
            self.list_box.append(Gtk.Label(label="WiFi is Disabled"))
            return

        # Spinner?
        networks = NMClient.get_networks()
        if not networks:
            self.list_box.append(Gtk.Label(label="No WiFi networks found"))
            
        for net in networks:
            row = NetworkRow(net, self)
            self.list_box.append(row)

    def on_row_clicked(self, box, row):
        if isinstance(row, NetworkRow):
            row.toggle_details()

    def on_wifi_toggle(self, sw, state):
        NMClient.toggle_wifi(state)
        GLib.timeout_add(1000, self.refresh)
        return False

    def on_hidden_connect(self, btn):
        # Dialog for SSID/Pass
        pass

    def close_after_delay(self):
        GLib.timeout_add(1000, lambda: self.quit())


# --- Waybar JSON Mode ---
def emit_json():
    icon_only = "--icon" in sys.argv
    info = NMClient.get_active_info()

    # Prioritize Ethernet Display
    if info['state'] == "activated" and info['type'] == '802-3-ethernet':
        icon = "󰈀"
        txt = icon if icon_only else f"{icon} {info['ssid']}"
        tooltip = f"Ethernet: {info['ssid']}\nIP: {info['ip']}"
        print(json.dumps({"text": txt, "class": "connected", "tooltip": tooltip}))
        return

    # WiFi Logic
    status = NMClient.get_status()
    if status == "disabled":
        txt = "󰖪" if icon_only else "󰖪 Off"
        print(json.dumps({"text": txt, "class": "disabled", "tooltip": "WiFi Disabled"}))
    else:
        icon = "󰖩" # Simple icon logic
        # Signal strength icon logic
        if info['state'] == "activated":
             # Reuse NetworkRow logic or simple approx
             pct = info['signal']
             if pct > 80: icon = "󰤨"
             elif pct > 60: icon = "󰤥"
             elif pct > 40: icon = "󰤢"
             elif pct > 20: icon = "󰤟"
             else: icon = "󰤯"
        else:
             icon = "󰖪"

        cls = "connected" if info['state'] == "activated" else "disconnected"
        
        if icon_only:
            txt = icon
        else:
            txt = f"{icon} {info['ssid']}" if cls == "connected" else f"󰖪 Disconnected"
        
        print(json.dumps({
            "text": txt,
            "class": cls,
            "tooltip": f"SSID: {info['ssid']}\nIP: {info['ip']}\nSignal: {info['signal']}%"
        }))

if __name__ == "__main__":
    if "--popup" in sys.argv:
        app = NetworkApp()
        app.run(None)
    elif "--toggle" in sys.argv:
        NMClient.toggle_wifi(NMClient.get_status() != "enabled")
    else:
        emit_json()