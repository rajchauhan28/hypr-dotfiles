#!/usr/bin/env python3
import sys
import subprocess

def main():
    mode = None
    if len(sys.argv) > 1:
        arg = sys.argv[1].lstrip('-')
        if arg in ('icon', 'status'):
            mode = 'status'
        elif arg in ('toggle', 't'):
            mode = 'toggle'
        elif arg in ('popup', 'p'):
            mode = 'popup'

    if mode == 'toggle':
        res = subprocess.run(["bluetoothctl", "show"], capture_output=True, text=True)
        if "Powered: yes" in res.stdout:
            subprocess.run(["bluetoothctl", "power", "off"])
        else:
            subprocess.run(["bluetoothctl", "power", "on"])
    elif mode == 'popup':
        subprocess.run(["auralink-bt"])
    elif mode == 'status':
        subprocess.run(["python3", "/home/reign/.config/waybar/scripts/auralink_status.py", "--mode", "bluetooth", "--icon"])
    else:
        subprocess.run(["python3", "/home/reign/.config/waybar/scripts/auralink_status.py", "--mode", "bluetooth"])

if __name__ == "__main__":
    main()
