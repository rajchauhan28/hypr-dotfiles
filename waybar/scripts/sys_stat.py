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
import time

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
    cpu_percent = psutil.cpu_percent(interval=1)
    ram_percent = psutil.virtual_memory().percent
    temp = get_cpu_temp()
    
    # Disk
    disk = psutil.disk_usage('/')
    disk_percent = disk.percent
    
    # Uptime
    uptime_seconds = time.time() - psutil.boot_time()
    uptime_string = f"{int(uptime_seconds // 3600)}h {int((uptime_seconds % 3600) // 60)}m"

    text = f" {cpu_percent:.0f}% |  {ram_percent:.0f}%"
    tooltip = f"CPU Usage: {cpu_percent:.0f}%\nRAM Usage: {ram_percent:.0f}%"

    if temp is not None:
        text += f" |  {temp:.0f}°C"
        tooltip += f"\nCPU Temp: {temp:.0f}°C"

    css_class = "normal"
    if ram_percent > 90 or cpu_percent > 90 or (temp is not None and temp > 85):
        css_class = "critical"
    elif ram_percent > 80 or cpu_percent > 80 or (temp is not None and temp > 70):
        css_class = "warning"

    with open("/tmp/sys_stats.json", "w") as f:
        json.dump({
            "cpu": cpu_percent, 
            "ram": ram_percent, 
            "temp": temp,
            "disk": disk_percent,
            "uptime": uptime_string
        }, f)

    print(json.dumps({
        'text': text,
        'tooltip': tooltip,
        'class': css_class
    }))

def popup():
    script = "/home/reign/.config/waybar/scripts/sys_stat_popup.py"
    
    # Check if script exists
    if os.path.exists(script):
        try:
            # Launch the python script detached
            subprocess.Popen(["python3", script], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
        except Exception as e:
            print(f"Error launching popup: {e}", file=sys.stderr)
    else:
        print(f"Error: Popup script not found at {script}", file=sys.stderr)

if __name__ == "__main__":
    # Initialize cpu_percent before the loop
    psutil.cpu_percent()

    if "--popup" in sys.argv:
        popup()
    else:
        emit_json()
