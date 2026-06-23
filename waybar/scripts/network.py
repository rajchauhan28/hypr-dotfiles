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

    if mode == 'toggle':
        res = subprocess.run(["nmcli", "radio", "wifi"], capture_output=True, text=True)
        if "enabled" in res.stdout:
            subprocess.run(["nmcli", "radio", "wifi", "off"])
        else:
            subprocess.run(["nmcli", "radio", "wifi", "on"])
    elif mode == 'status':
        subprocess.run(["python3", "/home/reign/.config/waybar/scripts/auralink_status.py", "--mode", "network", "--icon"])
    else:
        subprocess.run(["python3", "/home/reign/.config/waybar/scripts/auralink_status.py", "--mode", "network"])

if __name__ == "__main__":
    main()
