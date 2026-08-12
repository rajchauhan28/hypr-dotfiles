#!/usr/bin/env python3
"""Single-shot system stats for the topbar panel. Emits one line of JSON.

Kept to one process per tick so the panel can poll cheaply while revealed.
CPU percent is derived from the delta against the previous invocation, which
is cached in /tmp; the first call after a cold start reports 0.
"""
import json
import os
import shutil
import subprocess
import time

CACHE = f"/tmp/quickshell-topbar-cpu-{os.getuid()}.json"
NET_CACHE = f"/tmp/quickshell-topbar-net-{os.getuid()}.json"


def _cpu_lines():
    """Aggregate line plus one per core, as (total, idle) tuples."""
    out = []
    try:
        with open("/proc/stat") as f:
            for line in f:
                if not line.startswith("cpu"):
                    break
                parts = [int(x) for x in line.split()[1:]]
                idle = parts[3] + (parts[4] if len(parts) > 4 else 0)
                out.append((sum(parts), idle))
    except (OSError, ValueError):
        pass
    return out


def cpu_percent():
    """Returns (aggregate percent, [per-core percent]). Both are deltas against
    the previous invocation, cached in /tmp; the first call reports zeroes."""
    now = _cpu_lines()
    if not now:
        return 0, []

    prev = []
    try:
        with open(CACHE) as f:
            prev = json.load(f).get("lines", [])
    except (OSError, ValueError, AttributeError):
        pass

    try:
        with open(CACHE, "w") as f:
            json.dump({"lines": now}, f)
    except OSError:
        pass

    def pct(i):
        if i >= len(prev) or i >= len(now):
            return 0
        dt = now[i][0] - prev[i][0]
        di = now[i][1] - prev[i][1]
        if dt <= 0:
            return 0
        return max(0, min(100, round(100.0 * (dt - di) / dt)))

    return pct(0), [pct(i) for i in range(1, len(now))]


def mem():
    info = {}
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                k, _, v = line.partition(":")
                info[k] = int(v.split()[0])
    except OSError:
        return 0, 0, 0
    total = info.get("MemTotal", 0)
    avail = info.get("MemAvailable", 0)
    used = total - avail
    pct = round(100.0 * used / total) if total else 0
    return pct, round(used / 1048576.0, 1), round(total / 1048576.0, 1)


def swap():
    info = {}
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                k, _, v = line.partition(":")
                info[k] = int(v.split()[0])
    except OSError:
        return 0
    total = info.get("SwapTotal", 0)
    free = info.get("SwapFree", 0)
    if not total:
        return 0
    return round(100.0 * (total - free) / total)


def disk():
    try:
        u = shutil.disk_usage("/")
        return round(100.0 * u.used / u.total), round(u.used / 1e9), round(u.total / 1e9)
    except OSError:
        return 0, 0, 0


def temperatures():
    """Return distinct CPU-package and system/board temperatures."""
    cpu_best = None
    system_best = None
    try:
        base = "/sys/class/hwmon"
        for hw in os.listdir(base):
            try:
                with open(f"{base}/{hw}/name") as f:
                    name = f.read().strip()
            except OSError:
                continue
            is_cpu = name in ("k10temp", "coretemp", "zenpower")
            is_system = name in ("acpitz", "thinkpad", "dell_smm", "asus")
            if not is_cpu and not is_system:
                continue
            for entry in sorted(os.listdir(f"{base}/{hw}")):
                if entry.startswith("temp") and entry.endswith("_input"):
                    try:
                        with open(f"{base}/{hw}/{entry}") as f:
                            val = int(f.read().strip()) / 1000.0
                        if is_cpu and (cpu_best is None or val > cpu_best):
                            cpu_best = val
                        if is_system and (system_best is None or val > system_best):
                            system_best = val
                    except (OSError, ValueError):
                        continue
    except OSError:
        pass

    thermal = None
    if system_best is None or cpu_best is None:
        try:
            with open("/sys/class/thermal/thermal_zone0/temp") as f:
                thermal = int(f.read().strip()) / 1000.0
        except (OSError, ValueError):
            thermal = 0
    if cpu_best is None:
        cpu_best = thermal
    if system_best is None:
        system_best = thermal
    return round(cpu_best or 0), round(system_best or 0)


def network_rate():
    """Aggregate non-loopback traffic as KiB/s since the previous poll."""
    rx = tx = 0
    try:
        with open("/proc/net/dev") as f:
            for line in f:
                if ":" not in line:
                    continue
                iface, values = line.split(":", 1)
                if iface.strip() == "lo":
                    continue
                fields = values.split()
                rx += int(fields[0])
                tx += int(fields[8])
    except (OSError, ValueError, IndexError):
        return {"down": 0, "up": 0}

    now = time.monotonic()
    previous = {}
    try:
        with open(NET_CACHE) as f:
            previous = json.load(f)
    except (OSError, ValueError, AttributeError):
        pass
    try:
        with open(NET_CACHE, "w") as f:
            json.dump({"rx": rx, "tx": tx, "time": now}, f)
    except OSError:
        pass

    elapsed = now - previous.get("time", now)
    if elapsed <= 0:
        return {"down": 0, "up": 0}
    return {
        "down": round(max(0, rx - previous.get("rx", rx)) / elapsed / 1024, 1),
        "up": round(max(0, tx - previous.get("tx", tx)) / elapsed / 1024, 1),
    }


def gpu():
    """NVIDIA telemetry via nvidia-smi, plus the iGPU's name.

    The dGPU is runtime-power-managed on this laptop, so its power state is
    checked FIRST — querying nvidia-smi on a suspended card wakes it, which
    would keep the discrete GPU spinning for the sake of a readout.
    """
    out = {"present": False, "asleep": False, "name": "", "util": 0,
           "temp": 0, "memUsed": 0, "memTotal": 0, "computeCapability": ""}

    dev = None
    try:
        base = "/sys/bus/pci/devices"
        for entry in sorted(os.listdir(base)):
            vendor_path = f"{base}/{entry}/vendor"
            class_path = f"{base}/{entry}/class"
            try:
                with open(vendor_path) as f:
                    vendor = f.read().strip()
                with open(class_path) as f:
                    cls = f.read().strip()
            except OSError:
                continue
            # 0x10de = NVIDIA, class 0x030000 = VGA controller
            if vendor == "0x10de" and cls.startswith("0x0300"):
                dev = entry
                break
    except OSError:
        pass

    if dev is None:
        return out

    out["present"] = True
    try:
        with open(f"/sys/bus/pci/devices/{dev}/power/runtime_status") as f:
            if f.read().strip() != "active":
                out["asleep"] = True
                return out
    except OSError:
        pass

    try:
        res = subprocess.run(
            ["nvidia-smi",
             "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,compute_cap",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=2)
        parts = [p.strip() for p in res.stdout.strip().split(",")]
        if len(parts) >= 5:
            out["name"] = parts[0].replace("NVIDIA ", "")
            out["util"] = int(float(parts[1]))
            out["temp"] = int(float(parts[2]))
            out["memUsed"] = int(float(parts[3]))
            out["memTotal"] = int(float(parts[4]))
            if len(parts) >= 6 and parts[5] not in ("", "N/A"):
                out["computeCapability"] = parts[5]
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return out


def uptime():
    try:
        with open("/proc/uptime") as f:
            secs = int(float(f.read().split()[0]))
    except (OSError, ValueError):
        return "unknown"
    d, rem = divmod(secs, 86400)
    h, rem = divmod(rem, 3600)
    m = rem // 60
    if d:
        return f"{d} day{'s' if d != 1 else ''}, {h} hr"
    if h:
        return f"{h} hour{'s' if h != 1 else ''}, {m} min"
    return f"{m} minute{'s' if m != 1 else ''}"


def loadavg():
    try:
        return os.getloadavg()[0]
    except OSError:
        return 0.0


def distro():
    try:
        with open("/etc/os-release") as f:
            for line in f:
                if line.startswith("PRETTY_NAME="):
                    return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return "Linux"


def battery():
    base = "/sys/class/power_supply"
    try:
        for entry in sorted(os.listdir(base)):
            if not entry.startswith("BAT"):
                continue
            with open(f"{base}/{entry}/capacity") as f:
                cap = int(f.read().strip())
            state = "Unknown"
            try:
                with open(f"{base}/{entry}/status") as f:
                    state = f.read().strip()
            except OSError:
                pass
            return {"present": True, "capacity": cap, "status": state}
    except (OSError, ValueError):
        pass
    return {"present": False, "capacity": 0, "status": ""}


def top_procs(n=12):
    """Top processes by RSS — cheap to read and stable between ticks."""
    out = []
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/statm") as f:
                rss_pages = int(f.read().split()[1])
            with open(f"/proc/{pid}/comm") as f:
                name = f.read().strip()
        except (OSError, ValueError, IndexError):
            continue
        out.append((rss_pages * 4096, name))
    out.sort(reverse=True)
    return [{"name": n_, "mem": round(b / 1048576.0)} for b, n_ in out[:n]]


cpu_pct, cpu_cores = cpu_percent()
mem_pct, mem_used, mem_total = mem()
disk_pct, disk_used, disk_total = disk()
cpu_temp, system_temp = temperatures()

print(json.dumps({
    "cpu": cpu_pct,
    "coreLoad": cpu_cores,
    "cores": os.cpu_count() or 0,
    "load": round(loadavg(), 2),
    "temp": cpu_temp,
    "systemTemp": system_temp,
    "mem": mem_pct,
    "memUsed": mem_used,
    "memTotal": mem_total,
    "swap": swap(),
    "disk": disk_pct,
    "diskUsed": disk_used,
    "diskTotal": disk_total,
    "uptime": uptime(),
    "kernel": os.uname().release,
    "distro": distro(),
    "host": os.uname().nodename,
    "battery": battery(),
    "gpu": gpu(),
    "network": network_rate(),
    "procs": top_procs(),
    "ts": int(time.time()),
}))
