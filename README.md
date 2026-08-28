# 🚀 Rajchauhan28's Hyprland Dotfiles & QuickShell Suite

A modern, fluid, and futuristic Hyprland desktop environment powered by a custom **QuickShell** UI suite (completely replacing Waybar with hardware-accelerated QML panels, side bars, dynamic islands, docks, and workspace overviews).

---

## ✨ Features & Highlights

- **⚡ Complete QuickShell Suite (Waybar Replaced)**:
  - **Top Panel (`topbar`)**: Expandable diagonal top-center curtain panel with Dashboard, Media Tab, Performance Metrics, and Workspaces view.
  - **Left Side Bar (`leftbar`)**: Always-visible 54px Waybar replacement with 12-hour IST clock, floating draggable always-on-top clock widget, workspace switcher with sliding active capsule, app quick launchers, overview trigger (`Super+Tab`), and an expanding power slider.
  - **Bottom Dock (`dock`)**: Modern glassmorphic dock with app launcher, window previews, running dots, spring-pop micro-animations, and pinned app management.
  - **Side Panel (`sidepanel`)**: Quick settings strip with volume, brightness, bluetooth, wifi, and system controls.
  - **Super + Tab Overview (`overview`)**: Interactive workspace and window manager with smooth card physics.
- **🎵 Real-Time Audio Visualizer**: Liquid dual-ring circumference waves surrounding rotating album art with real-time PulseAudio/PipeWire spectrum analysis (`spectrum.py`).
- **🖥️ Hardware-Adaptive Install**: The installer reads DMI and PCI data and
  configures itself for the machine it is actually on.
  - **Any vendor**: the Predator/Nitro turbo key is bound only on an Acer gaming
    laptop, where the installer also offers to build the `linuwu_sense` module
    and install the pacman hook that rebuilds it on every kernel upgrade
    (there is no DKMS, so without the hook a kernel update silently leaves the
    module behind). Only after you say yes -- it needs root. The driver source
    is vendored under `stow_base/.local/share/damx-driver/source/` and is
    **GPL-3, not covered by this repository's MIT licence**; see the README
    there for its lineage and why it cannot simply be fetched from upstream.
  - **Any GPU**: `envycontrol` and the GPU-switching keybind appear only with an
    NVIDIA GPU present. The VA-API driver is picked to match the real hardware
    (`iHD` for Intel, `radeonsi` for AMD, `nvidia` for an NVIDIA-only box) --
    the wrong one breaks hardware video decode.
  - **Laptop or desktop**: the AC/battery refresh-rate daemon only starts where
    there is a battery to react to.
  - **Bluetooth**: AuraLink's auto-connect daemon is left enabled only on a
    machine that actually has a radio.
  - Results are written to `~/.config/hypr/hardware.{conf,lua}`, which the
    Hyprland config reads. Re-run `Install.sh` after a hardware change.
- **📐 Screen-Aware Scaling**: Panel geometry ships tuned for 1920x1200 and is
  rescaled at install time to the detected screen -- 1366x768, 1080p, 1440p and
  4K all get proportionate icons, bars and dashboards. Scaling uses *logical*
  resolution, so a 4K panel at compositor scale 2 is correctly treated as
  1920x1080 rather than doubled. Every value stays editable in the Settings app
  (`Super + ,`).
- **📡 AuraLink**: the Wi-Fi/Bluetooth manager the sidepanel and the app menu
  launch is **built from source** at install time
  ([rajchauhan28/auralink](https://github.com/rajchauhan28/auralink)) rather
  than committed here as a 23 MB x86-64 binary that silently went stale. Its
  own installer sets up and enables the Bluetooth auto-connect systemd unit.
- **🛡️ Automated Installer & Safety Rollback**:
  - `Install.sh`: One-line automated Arch Linux installer that sets up QuickShell, Qt6 dependencies, fonts, systemd services, and replaces Waybar.
  - `rollback.sh`: Unstows this repository and restores the most recent
    `~/.dotfiles_backup_<timestamp>` that `Install.sh` created. It never
    deletes the repository itself.

---

## 📦 Quick Installation (Arch Linux / Hyprland)

Run the one-line installer directly in your terminal:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rajchauhan28/hypr-dotfiles/refs/heads/main/Install.sh)
```

### Manual Installation Method

1. Clone the repository:
   ```bash
   git clone https://github.com/rajchauhan28/hypr-dotfiles.git
   cd hypr-dotfiles
   ```
2. Run the installer:
   ```bash
   chmod +x Install.sh
   ./Install.sh
   ```

---

## 🔄 Rollback Option

If you ever need to restore your previous configuration, simply run:

```bash
./rollback.sh
```

It unstows the dotfiles and copies back the newest `~/.dotfiles_backup_<timestamp>`
directory written by `Install.sh`. Your clone of this repository is left in
place -- remove it yourself if you no longer want it.

### Per-user files

`settings.json`, the two `pinned.json` files and `walllust/config.json` are
written by the running shell, so they are **not** tracked. The repository ships
each as a `.default`, which `Install.sh` copies into place only when the real
file is missing -- your own tweaks survive every `git pull`.

---

## ⌨️ Keybindings Quick Reference

| Keybinding | Action |
| :--- | :--- |
| `Super + TAB` | Toggle Super+Tab Workspace & Window Overview |
| `Super + O` | Reload the QuickShell suite |
| `Super + Shift + R` | Reload the QuickShell suite (same action as `Super + O`) |
| `Super + ,` | Open the Settings app |
| `Super + L` | Lock the session |
| `Super + I` | Toggle Quick Settings Side Panel |
| `Super + D` | Toggle Bottom Dock |
| `Super + /` | Keybinding cheatsheet |
| `Super + Enter` | Launch Terminal |
| `Super + R` | Application Launcher |
| `Super + Q` | Close Focused Window |
| `Super + Alt + G` | Game Mode (disable external monitors) |
| `Super + Shift + G` | GPU mode & power tweaks (GPU entries need NVIDIA) |

---

## 📄 License

Licensed under the [MIT License](LICENSE).
