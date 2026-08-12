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
- **🛡️ Automated Installer & Safety Rollback**:
  - `Install.sh`: One-line automated Arch Linux installer that sets up QuickShell, Qt6 dependencies, fonts, systemd services, and replaces Waybar.
  - `rollback.sh`: One-click script to safely restore previous dotfiles backup (`hypr-dotfiles-old`).

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

---

## ⌨️ Keybindings Quick Reference

| Keybinding | Action |
| :--- | :--- |
| `Super + TAB` | Toggle Super+Tab Workspace & Window Overview |
| `Super + O` | Reload QuickShell Daemons (Topbar, Leftbar, Dock, Sidepanel) |
| `Super + Shift + R` | Stop QuickShell Daemons |
| `Super + I` | Toggle Quick Settings Side Panel |
| `Super + D` | Toggle Bottom Dock |
| `Super + Enter` | Launch Terminal |
| `Super + R` | Application Launcher |
| `Super + Q` | Close Focused Window |

---

## 📄 License

Licensed under the [MIT License](LICENSE).
