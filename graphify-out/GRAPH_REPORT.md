# Graph Report - hypr-dotfiles  (2026-08-12)

## Corpus Check
- 67 files · ~2,899,499 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 258 nodes · 300 edges · 61 communities (34 shown, 27 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e0de8643`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- sysinfo.py
- Install.sh
- syspanel.py
- hypr-dotfiles
- wallpapers.py
- smart_gpu.py
- calendar_store.py
- ClockPopup
- SysStatPopup
- apps.py
- intro.py
- artcolor.py
- holidays_in.py
- spectrum.py
- sys_stat.py
- wallpaper_switcher_backup.sh
- brightnesscontrol.sh
- wlogout/README.md
- events.py
- background_apps.py
- media_info.py
- system-update.sh
- bluetooth.py
- network.py
- display_switcher.sh
- gamemode.sh
- gpu_switcher.sh
- menu_fix.sh
- mpvpaper-stop.sh
- screenshot.sh
- toggle_overview.sh
- wallpaper_switcher.sh
- waybar_hider.sh
- hyprctl-compat.sh
- settings/launch.sh
- updates.sh
- widgets/launch.sh
- readonlyFSfix.sh
- check_monitors.sh
- clip-delete.sh
- clip-select.sh
- clipse-delete.sh
- clipse-select.sh
- kdeconnect.sh
- theme_switcher.sh
- sys_update.sh
- anction

## God Nodes (most connected - your core abstractions)
1. `run()` - 11 edges
2. `msg()` - 9 edges
3. `main()` - 9 edges
4. `listing()` - 9 edges
5. `status()` - 8 edges
6. `ClockPopup` - 8 edges
7. `SysStatPopup` - 8 edges
8. `main()` - 7 edges
9. `hypr-dotfiles` - 7 edges
10. `run_cmd()` - 5 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (61 total, 27 thin omitted)

### Community 0 - "sysinfo.py"
Cohesion: 0.11
Nodes (12): _cpu_lines(), cpu_percent(), gpu(), network_rate(), Return distinct CPU-package and system/board temperatures., Aggregate non-loopback traffic as KiB/s since the previous poll., Aggregate line plus one per core, as (total, idle) tuples., NVIDIA telemetry via nvidia-smi, plus the iGPU's name. The dGPU is runtime-… (+4 more)

### Community 1 - "Install.sh"
Cohesion: 0.19
Nodes (18): ALL_CONFIG_DIRS, build_fastfetch_from_source(), C_BLUE, C_CYAN, C_GREEN, C_RED, C_RESET, C_YELLOW (+10 more)

### Community 2 - "syspanel.py"
Cohesion: 0.35
Nodes (13): bluetooth(), brightness(), _bt_devices(), default_sink_name(), main(), Returns stdout, or "" for anything that fails. The panel must render even when…, Parse `wpctl status` for output devices. The default one is starred., run() (+5 more)

### Community 3 - "hypr-dotfiles"
Cohesion: 0.15
Nodes (12): Contributing, Dependencies, hypr-dotfiles, Installation, Just Run the `Install.sh` file, Key Features and Highlights, License, Rajchauhan28's Dotfiles (+4 more)

### Community 4 - "wallpapers.py"
Cohesion: 0.29
Nodes (11): current_wallpaper(), listing(), load_cache(), main(), palette(), probe_image(), probe_video(), Extract a frame once, cached by path+mtime. (+3 more)

### Community 5 - "smart_gpu.py"
Cohesion: 0.50
Nodes (8): get_battery_info(), get_envy_mode(), main(), notify(), run_cmd(), set_perf_mode(), set_refresh_rate(), set_visual_optimizations()

### Community 6 - "calendar_store.py"
Cohesion: 0.42
Nodes (8): load(), main(), Returns the parsed dict, or None if unreadable/corrupt/wrong shape., Refresh the backup once per day, from the last known-good primary., _read(), rotate_backup(), save(), _write_atomic()

### Community 9 - "apps.py"
Cohesion: 0.39
Nodes (7): clean_exec(), collect(), data_dirs(), main(), parse(), Every applications/ directory, highest precedence first., Read the [Desktop Entry] group only. Later groups are actions, and their…

### Community 10 - "intro.py"
Cohesion: 0.39
Nodes (7): create_layout(), get_cached_static_info(), get_detailed_sys_info(), hex_to_ansi(), load_theme_colors(), main(), Retrieves heavy info (Packages, CPU, GPU) from cache or runs commands.

### Community 11 - "artcolor.py"
Cohesion: 0.47
Nodes (5): accent_of(), fetch(), main(), Return a local path for `url`, downloading it once if it is remote., Pick a saturated, mid-bright colour, then normalise it for a dark panel.

### Community 12 - "holidays_in.py"
Cohesion: 0.53
Nodes (5): _add_pipx_venv_to_path(), fallback(), from_package(), main(), pipx installs into an isolated venv, so the system interpreter cannot import…

### Community 13 - "spectrum.py"
Cohesion: 0.47
Nodes (5): band_edges(), default_monitor(), main(), The monitor source of the current default sink, or a sensible fallback., Log-spaced FFT bin edges from ~40Hz to ~16kHz. Linear bins would give the…

### Community 14 - "sys_stat.py"
Cohesion: 0.40
Nodes (4): emit_json(), get_cpu_temp(), Gets CPU temperature., Emits JSON for Waybar.

### Community 15 - "wallpaper_switcher_backup.sh"
Cohesion: 0.90
Nodes (4): change_current(), change_swww(), wallpaper_switcher_backup.sh script, switch()

### Community 16 - "brightnesscontrol.sh"
Cohesion: 0.70
Nodes (4): get_brightness_info(), get_icon(), print_error(), brightnesscontrol.sh script

### Community 17 - "wlogout/README.md"
Cohesion: 0.40
Nodes (4): install, refer from:, usage, wlogout-theme

### Community 18 - "events.py"
Cohesion: 0.83
Nodes (3): load_events(), main(), save_events()

### Community 19 - "background_apps.py"
Cohesion: 0.83
Nodes (3): emit_json(), get_running(), popup_show()

### Community 20 - "media_info.py"
Cohesion: 0.83
Nodes (3): main(), pc(), safe_json()

### Community 21 - "system-update.sh"
Cohesion: 1.00
Nodes (3): get_aur_helper(), pkg_installed(), system-update.sh script

## Knowledge Gaps
- **43 isolated node(s):** `C_RESET`, `C_RED`, `C_GREEN`, `C_YELLOW`, `C_BLUE` (+38 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **27 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `C_RESET`, `C_RED`, `C_GREEN` to the rest of the system?**
  _43 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `sysinfo.py` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._