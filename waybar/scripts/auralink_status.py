import sys
import json
import subprocess
import argparse
import re
import os

def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode().strip()
    except:
        return ""

def get_network_status():
    # Prioritize Ethernet
    active_out = run(["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,STATE", "connection", "show", "--active"])
    
    conn = None
    for line in active_out.splitlines():
        parts = line.split(':')
        if len(parts) >= 4:
            if parts[1] == '802-3-ethernet':
                conn = parts
                break
            if parts[1] == '802-11-wireless' and conn is None:
                conn = parts
    
    if not conn:
        return {"text": "󰖪 Disconnected", "class": "disconnected", "tooltip": "No active connection"}

    name, ctype, dev, state = conn[0], conn[1], conn[2], conn[3]
    
    if ctype == '802-3-ethernet':
        icon = "󰈀"
        text = f"{icon} {name}"
    else:
        # WiFi Signal
        sig_out = run(["nmcli", "-t", "-f", "SIGNAL", "device", "wifi", "list", "ifname", dev])
        try:
            sig = int(sig_out.splitlines()[0])
        except:
            sig = 0
            
        if sig >= 80: icon = "󰤨"
        elif sig >= 60: icon = "󰤥"
        elif sig >= 40: icon = "󰤢"
        elif sig >= 20: icon = "󰤟"
        else: icon = "󰤯"
        text = f"{icon} {name}"

    # IP
    ip = run(["ip", "-4", "-o", "addr", "show", dev])
    ip_match = re.search(r'inet\s+([0-9.]+)', ip)
    ip_addr = ip_match.group(1) if ip_match else "Unknown"
    
    return {
        "text": text,
        "class": "connected",
        "tooltip": f"SSID: {name}\nIP: {ip_addr}\nType: {ctype}\nDevice: {dev}"
    }

def get_bluetooth_status():
    power_out = run(["bluetoothctl", "show"])
    powered = "Powered: yes" in power_out
    
    if not powered:
        return {"text": "󰂲 Off", "class": "off", "tooltip": "Bluetooth is powered off"}

    # Get connected devices
    devs_out = run(["bluetoothctl", "devices", "Paired"])
    connected = []
    for line in devs_out.splitlines():
        m = re.match(r'Device\s+([0-9A-F:]+)\s+(.+)', line)
        if m:
            mac, name = m.group(1), m.group(2)
            info = run(["bluetoothctl", "info", mac])
            if "Connected: yes" in info:
                batt_match = re.search(r"Battery Percentage:.*?(\d+)", info)
                batt = f" ({batt_match.group(1)}%)" if batt_match else ""
                connected.append(f"{name}{batt}")

    if not connected:
        return {"text": "󰂯 On", "class": "on", "tooltip": "Bluetooth on, no devices connected"}

    # Use first device for text
    primary = connected[0]
    return {
        "text": f"󰂯 {primary}",
        "class": "connected",
        "tooltip": "Connected Devices:\n" + "\n".join([f"• {d}" for d in connected])
    }

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["network", "bluetooth"], required=True)
    args = parser.parse_args()

    if args.mode == "network":
        print(json.dumps(get_network_status()))
    else:
        print(json.dumps(get_bluetooth_status()))
