#!/usr/bin/env python3
import os
import time
import subprocess
import psutil

# Configuration
THRESHOLD_BATTERY = 40  # Percent
POLL_INTERVAL = 5       # Seconds
MONITOR = "eDP-1"        # Internal monitor name
REFRESH_HIGH = 165       # AC Refresh Rate
REFRESH_LOW = 60         # Battery Refresh Rate

def get_battery_info():
    battery = psutil.sensors_battery()
    if battery:
        return battery.percent, battery.power_plugged
    return None, None

def run_cmd(cmd):
    try:
        subprocess.run(cmd, shell=True, capture_output=True)
    except:
        pass

def notify(title, message, icon="system-run"):
    run_cmd(f'notify-send "{title}" "{message}" -i {icon}')

def set_perf_mode(mode):
    # mode: 'performance' or 'powersave'
    # Try using power-profiles-daemon first (best practice)
    if subprocess.run(["command", "-v", "powerprofilesctl"], shell=True, capture_output=True).returncode == 0:
        run_cmd(f"powerprofilesctl set {mode}")
    else:
        # Fallback to sysfs (requires sudo/udev)
        try:
            for i in range(os.cpu_count()):
                path = f"/sys/devices/system/cpu/cpu{i}/cpufreq/scaling_governor"
                if os.path.exists(path):
                    # This might fail without sudo
                    pass
        except:
            pass

def set_refresh_rate(rate):
    run_cmd(f"hyprctl keyword monitor {MONITOR}, preferred, auto, 1, @{rate}")

def set_visual_optimizations(is_battery):
    if is_battery:
        run_cmd("hyprctl keyword decoration:blur:enabled false")
        run_cmd("hyprctl keyword decoration:shadow:enabled false")
        run_cmd("brightnessctl set 30%")
    else:
        run_cmd("hyprctl keyword decoration:blur:enabled true")
        run_cmd("hyprctl keyword decoration:shadow:enabled true")
        run_cmd("brightnessctl set 80%")

def get_envy_mode():
    try:
        res = subprocess.run(["envycontrol", "-q"], capture_output=True, text=True)
        return res.stdout.strip()
    except:
        return "unknown"

def main():
    last_plugged = None
    print("Smart GPU Optimizer started.")
    
    while True:
        percent, plugged = get_battery_info()
        if percent is None: continue

        if plugged != last_plugged:
            if plugged:
                # On AC
                set_visual_optimizations(False)
                if percent > THRESHOLD_BATTERY:
                    notify("Power: AC", f"High Performance Mode ({percent}%). 165Hz Enabled.")
                    set_refresh_rate(REFRESH_HIGH)
                    set_perf_mode("performance")
                    if get_envy_mode() != "nvidia":
                        notify("Performance Tip", "Switch to NVIDIA for max power! (Super+Shift+G)")
                else:
                    notify("Power: AC", f"Charging ({percent}%). Low power mode until {THRESHOLD_BATTERY}%.")
            else:
                # On Battery
                notify("Power: Battery", "Switching to Eco Mode. 60Hz + No Blur.")
                set_refresh_rate(REFRESH_LOW)
                set_visual_optimizations(True)
                set_perf_mode("powersave")
                if get_envy_mode() == "nvidia":
                    notify("Battery Tip", "In NVIDIA mode! Switch to Integrated to save life.")
            
            last_plugged = plugged
        
        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()
