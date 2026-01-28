#!/usr/bin/env python3
"""
calendar_time.py
- Emits JSON with either time or date depending on toggle stored in a tmp file.
- On --toggle toggles which is shown.
- On click the Waybar config calls --toggle which will flip between time/date.
"""

import sys, json, time, os, subprocess
from datetime import datetime

TOGGLE_FILE = "/tmp/waybar_calendar_time_mode"

def read_mode():
    if not os.path.exists(TOGGLE_FILE):
        with open(TOGGLE_FILE, "w") as f:
            f.write("time")
        return "time"
    else:
        with open(TOGGLE_FILE) as f:
            return f.read().strip()

def write_mode(m):
    with open(TOGGLE_FILE, "w") as f:
        f.write(m)

def emit():
    mode = read_mode()
    now = datetime.now()
    if mode == "time":
        icon = ""
        text = now.strftime("%H:%M")
        tooltip = now.strftime("%H:%M:%S %Z")
    else:
        icon = "󰃭"
        text = now.strftime("%d-%m-%y")
        tooltip = now.strftime("%A, %B %d, %Y")
    
    text = f"{icon} {text}"
    print(json.dumps({"text": text, "tooltip": tooltip}))
    sys.stdout.flush()

def popup():
    script = "/home/reign/.config/waybar/scripts/calendar_popup.py"
    env = os.environ.copy()
    # env["LD_PRELOAD"] = "/usr/lib/libgtk4-layer-shell.so"
    subprocess.Popen(["python3", script], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)

if __name__ == "__main__":
    if "--toggle" in sys.argv:
        mode = read_mode()
        write_mode("date" if mode == "time" else "time")
        # no output necessary; Waybar will call the module again on interval
    elif "--popup" in sys.argv:
        popup()
    else:
        emit()

