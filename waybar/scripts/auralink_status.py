import sys
import json
import subprocess
import argparse
import os

def get_network_status():
    try:
        # Force headless mode by clearing display env vars
        env = os.environ.copy()
        env["DISPLAY"] = ""
        env["WAYLAND_DISPLAY"] = ""
        res = subprocess.check_output(["auralink", "status"], env=env, stderr=subprocess.DEVNULL, timeout=2).decode()
        data = json.loads(res)
    except:
        return {"text": "󰖪 Error", "class": "disconnected", "tooltip": "Auralink not running or error"}

    active = data.get("active_network")
    if not active or not active.get("connected"):
        return {"text": "󰖪 Disconnected", "class": "disconnected", "tooltip": "No active network"}

    if active.get("is_ethernet"):
        icon = "󰈀"
        text = f"{icon} Ethernet"
    else:
        sig = active.get("signal", 0)
        if sig >= 80: icon = "󰤨"
        elif sig >= 60: icon = "󰤥"
        elif sig >= 40: icon = "󰤢"
        elif sig >= 20: icon = "󰤟"
        else: icon = "󰤯"
        text = f"{icon} {active.get('ssid', 'WiFi')}"

    vpns = data.get("active_vpns", [])
    vpn_status = "\nVPNs: " + ", ".join([v['name'] for v in vpns]) if vpns else ""
    
    return {
        "text": text,
        "class": "connected",
        "tooltip": f"SSID: {active.get('ssid')}\nSignal: {active.get('signal')}%\nSecurity: {active.get('security')}{vpn_status}"
    }

def get_bluetooth_status():
    try:
        # Force headless mode by clearing display env vars
        env = os.environ.copy()
        env["DISPLAY"] = ""
        env["WAYLAND_DISPLAY"] = ""
        res = subprocess.check_output(["auralink-bt", "status"], env=env, stderr=subprocess.DEVNULL, timeout=2).decode()
        data = json.loads(res)
    except:
        return {"text": "󰂲 Error", "class": "off", "tooltip": "Auralink-BT error"}

    if not data.get("powered"):
        return {"text": "󰂲 Off", "class": "off", "tooltip": "Bluetooth is powered off"}

    connected = data.get("connected_devices", [])
    if not connected:
        return {"text": "󰂯 On", "class": "on", "tooltip": "Bluetooth on, no devices"}

    # Use first connected device
    dev = connected[0]
    icon = "󰂯"
    name = dev.get("name", "Unknown")
    batt = f" ({dev.get('battery')}%)" if dev.get("battery") is not None else ""
    
    tooltip = "Connected Devices:\n" + "\n".join([f"• {d['name']} ({d.get('battery', 'N/A')}%)" for d in connected])

    return {
        "text": f"{icon} {name}{batt}",
        "class": "connected",
        "tooltip": tooltip
    }

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["network", "bluetooth"], required=True)
    args = parser.parse_args()

    if args.mode == "network":
        print(json.dumps(get_network_status()))
    else:
        print(json.dumps(get_bluetooth_status()))
