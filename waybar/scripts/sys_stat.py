#!/usr/bin/env python3
"""
sys_stats.py
- Emits JSON with CPU/RAM/Temp icons and percentages for Waybar.
- On --popup opens a webview popup with small live graphs.
Requirements: python3-psutil
"""

import sys
import json
import psutil
import subprocess
import os
import os

def get_cpu_temp():
    """Gets CPU temperature."""
    try:
        # Note: sensor names can vary. 'coretemp' and 'k10temp' are common.
        # You might need to adjust this for your specific hardware.
        temps = psutil.sensors_temperatures()
        if not temps:
            return None

        if 'coretemp' in temps:
            return temps['coretemp'][0].current
        if 'k10temp' in temps:
            return temps['k10temp'][0].current
        
        # Fallback to the first available sensor
        for name in temps:
            if len(temps[name]) > 0:
                return temps[name][0].current

    except (AttributeError, KeyError):
        pass
    return None

def emit_json():
    """Emits JSON for Waybar."""
    cpu_percent = psutil.cpu_percent()
    ram_percent = psutil.virtual_memory().percent
    temp = get_cpu_temp()

    text = f" {cpu_percent:.0f}% |  {ram_percent:.0f}%"
    tooltip = f"CPU Usage: {cpu_percent:.0f}%\nRAM Usage: {ram_percent:.0f}%"

    if temp is not None:
        text += f" |  {temp:.0f}°C"
        tooltip += f"\nCPU Temp: {temp:.0f}°C"

    css_class = "normal"
    if ram_percent > 90 or cpu_percent > 90 or (temp is not None and temp > 85):
        css_class = "critical"
    elif ram_percent > 80 or cpu_percent > 80 or (temp is not None and temp > 70):
        css_class = "warning"

    print(json.dumps({
        'text': text,
        'tooltip': tooltip,
        'class': css_class
    }))

def popup():
    env = os.environ.copy()
    env["DISPLAY"] = ":0"
    env["PATH"] = f"{env["PATH"]}:/home/reign/.local/bin"
    subprocess.Popen(["/home/reign/.config/waybar/scripts/webview_plot.py"], env=env)

if __name__ == "__main__":
    # Initialize cpu_percent before the loop
    psutil.cpu_percent()

    if "--popup" in sys.argv:
        popup()
    else:
        emit_json()