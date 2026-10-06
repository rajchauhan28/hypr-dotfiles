//@ pragma UseQApplication
// QApplication mode is required for platform menus -- the system tray's
// right-click menus (QsMenuAnchor) refuse to open without it. The pragma is
// only honoured on the ROOT QML file, so it has to live here: leftbar/ still
// carries its own copy from when it was its own `qs -c leftbar` process, but
// that copy has been dead since the panels were consolidated into this file.

// Consolidated shell: one QML engine hosting every panel that used to be its
// own `qs -d -c <name>` process (topbar, leftbar, dock, sidepanel,
// notifications, desktop_clock).
//
// The lockscreen is deliberately NOT here — see lock/lock.sh. It stays a
// separate daemon so that reloading the bars cannot drop an active lock and a
// QML fault in a panel cannot take the lockscreen down while the session is
// locked.
//
// Imports are QUALIFIED on purpose: every panel directory carries its own
// `pragma Singleton` Theme.qml (and topbar/settings both define Card.qml), so
// an unqualified directory import would collide on those names. Each component
// still resolves Theme/Card from its own directory internally.
import Quickshell
import Quickshell.Io

import "topbar" as TopbarNS
import "leftbar" as LeftbarNS
import "dock" as DockNS
import "sidepanel" as SidepanelNS
import "notifications" as NotificationsNS
import "widgets/desktop_clock" as DesktopClockNS
import "launcher" as LauncherNS
import "osd" as OsdNS
import "clipboard" as ClipboardNS
import "wallpaper" as WallpaperNS

ShellRoot {
    TopbarNS.TopbarPanel {}
    LeftbarNS.LeftbarPanel {}
    DockNS.DockPanel {}
    SidepanelNS.SidepanelPanel {}
    NotificationsNS.NotificationsPanel {}
    DesktopClockNS.DesktopClockPanel {}
    LauncherNS.LauncherPanel {}
    OsdNS.OsdPanel {}
    ClipboardNS.ClipboardPanel {}
    WallpaperNS.WallpaperCarousel {}
    // Floating lyrics window. Lives at shell scope, not inside the topbar, so
    // it survives the dashboard being closed -- which is the whole point of
    // popping it out.
    TopbarNS.LyricsPopout {}

    // Keeps Hyprland's liquid glass (hypr/glass.lua) in step with the theme.
    // glass.lua reads the mode from settings.json whenever Hyprland evaluates
    // its config, so a theme change only has to trigger a config reload --
    // which also re-applies the settings window's glass rule to the open
    // window. Never on the first read: Hyprland read the same file when it
    // started, and a shell hot-reload must not reload the compositor.
    Scope {
        id: themeSync

        property string mode: ""

        FileView {
            path: Quickshell.env("HOME") + "/.config/quickshell/settings.json"
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                var m = "dark";
                try {
                    var t = JSON.parse(text()).theme;
                    if (t && (t.mode === "light" || t.mode === "glass"))
                        m = t.mode;
                } catch (e) {
                    return; // mid-write; the next change event re-reads it
                }
                if (themeSync.mode !== "" && themeSync.mode !== m)
                    hyprReload.running = true;
                themeSync.mode = m;
            }
        }

        Process {
            id: hyprReload
            command: ["hyprctl", "reload"]
        }
    }
}
