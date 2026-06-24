import os
import platform
import getpass
import shutil
import re
import subprocess
import json
import time
from terminaltexteffects.effects.effect_beams import Beams
from terminaltexteffects import Color

# --- CONFIGURATION ---
CACHE_FILE = os.path.expanduser("~/.cache/reignshell_sysinfo.json")
CACHE_DURATION = 86400  # 24 Hours in seconds

LOGO = [
    "                   -`",
    "                  .o+`",
    "                 `ooo/",
    "                `+oooo:",
    "               `+oooooo:",
    "               -+oooooo+:",
    "             `/:-:++oooo+:",
    "            `/++++/+++++++:",
    "           `/++++++++++++++:",
    "          `/+++ooooooooooooo:",
    "         ./ooosssso++osssssso+`",
    "        .oossssso-````/ossssss+`",
    "       -osssssso.      :ssssssso.",
    "      :osssssss/        osssssssso.",
    "     /ossssssss/        +sssssssssso.",
    "   `/ossssso+/:-        -:/+osssso+-",
    "  `+sso+:-`                 `.-/+oso:",
    " `++:.                           `-/+/",
    " .`                                 `/",
]

def hex_to_ansi(hex_color):
    hex_color = hex_color.lstrip('#')
    try:
        r = int(hex_color[0:2], 16)
        g = int(hex_color[2:4], 16)
        b = int(hex_color[4:6], 16)
        return f"\033[38;2;{r};{g};{b}m"
    except ValueError:
        return "\033[0m"

def load_theme_colors():
    colors = {
        "logo": "\033[1;36m",      # Cyan
        "user": "\033[1;36m",      # Cyan
        "key": "\033[1;33m",       # Yellow
        "value": "\033[0m",        # Default
        "reset": "\033[0m",
        "palette": []
    }
    wal_path = os.path.expanduser("~/.cache/wal/colors.json")
    if os.path.exists(wal_path):
        try:
            with open(wal_path, 'r') as f:
                data = json.load(f)
                wal_colors = data.get('colors', {})
                
                # Extract palette for effect
                palette = []
                for i in range(1, 7):
                    key = f"color{i}"
                    if key in wal_colors:
                        palette.append(wal_colors[key])
                if palette:
                    colors['palette'] = palette

                if 'color6' in wal_colors:
                    colors['logo'] = hex_to_ansi(wal_colors['color6'])
                    colors['user'] = hex_to_ansi(wal_colors['color6'])
                
                if 'color3' in wal_colors:
                    colors['key'] = hex_to_ansi(wal_colors['color3'])
        except Exception:
            pass 
    return colors

THEME = load_theme_colors()

def get_cached_static_info():
    """Retrieves heavy info (Packages, CPU, GPU) from cache or runs commands."""
    
    # Defaults
    data = {
        "packages": "Unknown",
        "cpu": "Unknown",
        "gpus": ["Unknown"],
        "timestamp": 0
    }

    # Try loading cache
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, 'r') as f:
                cached_data = json.load(f)
                # If cache is fresh (less than CACHE_DURATION old), return it
                if time.time() - cached_data.get("timestamp", 0) < CACHE_DURATION:
                    return cached_data
        except:
            pass

    # --- HEAVY OPERATIONS (Only run if cache missing or old) ---
    
    # 1. Packages (Slowest)
    try:
        p = subprocess.run("pacman -Qq | wc -l", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if p.returncode == 0:
            data["packages"] = f"{p.stdout.decode().strip()} (pacman)"
    except:
        pass

    # 2. CPU
    try:
        data["cpu"] = platform.processor()
        with open("/proc/cpuinfo", "r") as f:
            for line in f:
                if "model name" in line:
                    cpu_text = line.split(":")[1].strip()
                    data["cpu"] = cpu_text.replace("(R)", "").replace("(TM)", "").replace(" CPU", "")
                    break
    except:
        pass

    # 3. GPU
    gpus_found = []
    try:
        p = subprocess.run(r"lspci | grep -i 'vga\|3d\|2d'", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if p.returncode == 0:
            for line in p.stdout.decode().strip().split('\n'):
                if ':' in line:
                    gpu_name = line.split(':')[-1].strip()
                    if "NVIDIA" in gpu_name:
                        gpu_name = gpu_name.split('[')[1].split(']')[0] if '[' in gpu_name else gpu_name
                    elif "Intel" in gpu_name:
                         gpu_name = gpu_name.replace("Corporation ", "").replace("Integrated Graphics Controller", "").strip()
                    if gpu_name:
                        gpus_found.append(gpu_name)
    except:
        pass
    
    if gpus_found:
        data["gpus"] = gpus_found

    # Save to cache
    data["timestamp"] = time.time()
    try:
        with open(CACHE_FILE, 'w') as f:
            json.dump(data, f)
    except:
        pass

    return data

def get_detailed_sys_info():
    try:
        # Load fast things immediately
        user = getpass.getuser()
        hostname = platform.node()
        os_name = "Arch Linux"
        kernel = platform.release()
        
        # Load slow things from cache
        static_data = get_cached_static_info()

        # Uptime (Fast - Always Realtime)
        uptime_str = "Unknown"
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.readline().split()[0])
                days = int(uptime_seconds // 86400)
                hours = int((uptime_seconds % 86400) // 3600)
                mins = int((uptime_seconds % 3600) // 60)
                if days > 0:
                    uptime_str = f"{days}d {hours}h {mins}m"
                else:
                    uptime_str = f"{hours}h {mins}m"
        except:
            pass

        shell = os.environ.get('SHELL', 'Unknown').split('/')[-1]

        # Memory (Fast - Always Realtime)
        memory = "Unknown"
        try:
            with open("/proc/meminfo", "r") as f:
                mem_total = 0
                mem_avail = 0
                for line in f:
                    if "MemTotal" in line:
                        mem_total = int(line.split()[1]) // 1024 
                    if "MemAvailable" in line:
                        mem_avail = int(line.split()[1]) // 1024
                mem_used = mem_total - mem_avail
                memory = f"{mem_used} MiB / {mem_total} MiB"
        except:
            pass

        # Disk (Fast - Always Realtime)
        disk = "Unknown"
        try:
            total, used, free = shutil.disk_usage("/")
            disk = f"{used // (2**30)} GiB / {total // (2**30)} GiB"
        except:
            pass

        de = os.environ.get("XDG_CURRENT_DESKTOP", os.environ.get("DESKTOP_SESSION", "Unknown"))

        c_user = THEME['user']
        c_key = THEME['key']
        c_rst = THEME['reset']
        
        info_list = [
            f"{c_user}{user}@{hostname}{c_rst}",
            "-------------------",
            f"{c_key}OS{c_rst}:       {os_name}",
            f"{c_key}Kernel{c_rst}:   {kernel}",
            f"{c_key}Uptime{c_rst}:   {uptime_str}",
            f"{c_key}Packages{c_rst}: {static_data['packages']}",
            f"{c_key}Shell{c_rst}:    {shell}",
            f"{c_key}DE/WM{c_rst}:    {de}",
            f"{c_key}CPU{c_rst}:      {static_data['cpu']}",
        ]
        
        for i, gpu in enumerate(static_data['gpus']):
            label = "GPU"
            if len(static_data['gpus']) > 1:
                label = f"GPU {i+1}"
            info_list.append(f"{c_key}{label}{c_rst}:       {gpu}")

        info_list.extend([
            f"{c_key}Memory{c_rst}:   {memory}",
            f"{c_key}Disk (/){c_rst}: {disk}",
        ])
        
        return info_list
    except Exception as e:
        return [f"Error: {e}"]

def create_layout():
    info = get_detailed_sys_info()
    logo_height = len(LOGO)
    info_height = len(info)
    max_height = max(logo_height, info_height)
    
    block_lines = []
    logo_width = max(len(line) for line in LOGO)
    gap = 4
    
    c_logo = THEME['logo']
    c_rst = THEME['reset']
    
    for i in range(max_height):
        if i < logo_height:
            logo_part = LOGO[i]
            padding_needed = logo_width - len(logo_part)
            logo_colored = f"{c_logo}{logo_part}{c_rst}" + (" " * padding_needed)
        else:
            logo_colored = " " * logo_width
        
        info_part = info[i] if i < info_height else ""
        block_lines.append(f"{logo_colored}{' ' * gap}{info_part}")

    left_pad = 2
    left_pad_str = " " * left_pad
    top_pad_lines = 1
    
    final_output = []
    for _ in range(top_pad_lines):
        final_output.append("")
        
    for line in block_lines:
        final_output.append(f"{left_pad_str}{line}")
        
    return "\n".join(final_output)

def main():
    text = create_layout()
    effect = Beams(text)
    
    effect.terminal_config.existing_color_handling = "dynamic"
    effect.effect_config.ciphertext_duration = 2
    effect.effect_config.final_gradient_hop_speed = 5
    effect.terminal_config.frame_rate = 180

    if THEME['palette']:
        gradient_colors = tuple(Color(c) for c in THEME['palette'])
        effect.effect_config.beam_gradient_stops = gradient_colors
    
    effect.effect_config.beam_delay = 5
    effect.effect_config.beam_row_interval = 10
    
    with effect.terminal_output() as terminal:
        for frame in effect:
            terminal.print(frame)

if __name__ == "__main__":
    main()
