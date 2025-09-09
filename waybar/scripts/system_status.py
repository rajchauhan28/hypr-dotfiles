#!/usr/bin/env python3
import psutil
import json

# Get cpu percentage (over 0.5 second)
cpu = psutil.cpu_percent(interval=0.5)

# Get memory percentage used
mem = psutil.virtual_memory().percent

# Try to get temperature (requires psutil >=5.7.0 and `sensors` support)
try:
    temps = psutil.sensors_temperatures()
    # Try commonly used temperature sensors
    temp = None
    for key in ('coretemp', 'cpu-thermal', 'k10temp', 'acpitz'):
        if key in temps:
            temp = temps[key][0].current
            break
    if temp is None and temps:
        # Fallback: take first available sensor
        temp = list(temps.values())[0][0].current
    temp = round(temp) if temp is not None else 'N/A'
except Exception:
    temp = 'N/A'

output = {
    "text": f" {cpu:.0f} |  {mem:.0f}% |  {temp}°C"
}
print(json.dumps(output))

