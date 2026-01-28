#!/usr/bin/env python3
import subprocess
import json
import sys

def get_notifications():
    try:
        # Get count of waiting notifications
        count_proc = subprocess.run(['swaync-client', '-c'], capture_output=True, text=True)
        count = count_proc.stdout.strip()
        
        # Check if Do Not Disturb is on
        dnd_proc = subprocess.run(['swaync-client', '-get-dnd'], capture_output=True, text=True)
        dnd = dnd_proc.stdout.strip() == "true"
        
        icon = "󰂛" if dnd else ""
        if count != "0" and count != "":
            text = f"{icon} •"
            css_class = "waiting"
        else:
            text = f"{icon}"
            css_class = "none"
            
        return {
            "text": text,
            "tooltip": f"Notifications: {count}\nDND: {'On' if dnd else 'Off'}",
            "class": css_class,
            "alt": "dnd" if dnd else "default"
        }
    except Exception:
        return {"text": "", "tooltip": "Notification service not responding"}

if __name__ == "__main__":
    print(json.dumps(get_notifications()))
