pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    property var cfg: ({})
    property string osName: "Linux"
    property string osIcon: ""
    property string backgroundSource: ""
    property bool backgroundIsVideo: false
    property var users: [{
        "username": Quickshell.env("USER"),
        "name": Quickshell.env("USER"),
        "icon": "",
        "current": true
    }]

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                theme.cfg = JSON.parse(text()) || ({});
            } catch (e) {}
        }
    }

    // ---- Light / dark / glass ------------------------------------------
    // settings.json picks the mode ({"theme": {"mode": ...}}) and
    // ../themes.json holds the light and glass palettes; both are re-read
    // live. Dark is every literal below, so a missing or broken themes.json
    // leaves this panel exactly as it looked before themes existed.
    property var themes: ({})

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/themes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                theme.themes = JSON.parse(text()) || ({});
            } catch (e) {}
        }
    }

    readonly property string mode: {
        var t = theme.cfg.theme;
        var m = t ? t.mode : "";
        return (m === "light" || m === "glass") ? m : "dark";
    }
    readonly property bool light: theme.mode === "light"
    readonly property bool glass: theme.mode === "glass"

    // A user override for the ACTIVE mode wins (settings app sections
    // "palette" = dark, "paletteLight", "paletteGlass"), then themes.json,
    // then the dark literal passed in.
    function col(key, def) {
        var sec = theme.light ? "paletteLight" : theme.glass ? "paletteGlass" : "palette";
        var p = theme.cfg[sec];
        if (p && typeof p[key] === "string" && p[key] !== "")
            return p[key];
        var t = theme.themes[theme.mode];
        if (t && typeof t[key] === "string" && t[key] !== "")
            return t[key];
        return def;
    }

    // Foreground wash at an alpha: white on dark and glass, black on light.
    // For hover fills, hairlines and tracks that used to be "#xxffffff".
    function ink(a) {
        return theme.light ? Qt.rgba(0, 0, 0, a) : Qt.rgba(1, 1, 1, a);
    }

    readonly property color panelBg: theme.col("panelBg", "#f2101014")
    readonly property color accent: theme.col("accent", "#e4e4e7")
    readonly property color onAccent: theme.col("onAccent", "#101014")
    readonly property color textPrimary: theme.col("textPrimary", "#f8fafc")
    readonly property color textSecondary: theme.col("textSecondary", "#a1a1aa")
    readonly property color textMuted: theme.col("textMuted", "#71717a")
    readonly property color danger: theme.col("danger", "#e06b6b")
    // Only glass draws this (the rim of a frosted card, see LockCard.qml).
    readonly property color panelBorder: theme.col("panelBorder", "#1cffffff")

    // The primary text colour at an alpha. The lock's text, glyphs and dial
    // ticks were "#xxf8fafc", i.e. textPrimary's dark literal at an alpha,
    // so dark reproduces them exactly and light turns them into dark ink.
    function fg(a) {
        var c = theme.textPrimary;
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // ---- Lock-screen chrome ---------------------------------------------
    // Floor under the wallpaper (shows before it loads, or when there is
    // none). Forced opaque whatever a palette says: the session-lock
    // surface must never become see-through.
    readonly property color lockBasePalette: theme.col("lockBase", "#101014")
    readonly property color lockBase: Qt.rgba(lockBasePalette.r, lockBasePalette.g,
                                              lockBasePalette.b, 1)
    // Wash over the wallpaper. Light needs a light one or its dark text
    // would sit on the dark wash.
    readonly property color lockScrim: theme.col("lockScrim", "#42000000")
    readonly property color lockWindow: theme.col("lockWindow", "#d21a191d")  // ss / mm windows
    readonly property color lockField: theme.col("lockField", "#a3141418")    // password pill
    readonly property color lockAvatar: theme.col("lockAvatar", "#5c101014")
    readonly property color lockButton: theme.col("lockButton", "#77101014")  // switch user
    readonly property color lockButtonHover: theme.col("lockButtonHover", "#9918181d")

    readonly property string lockIcon: {
        var s = theme.cfg.lockscreen;
        if (!s || !s.icon) return "";
        return s.icon;
    }

    readonly property string effectiveLockIcon: lockIcon !== "" ? lockIcon : osIcon
    readonly property bool hasCustomLockIcon: lockIcon !== ""

    Process {
        running: true
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/settings/system_info.py"]
        stdout: SplitParser {
            onRead: output => {
                try {
                    var info = JSON.parse(output.trim());
                    theme.osName = info.name || "Linux";
                    theme.osIcon = info.icon || Quickshell.iconPath(info.logoName || info.id, true);
                } catch (e) {}
            }
        }
    }

    Process {
        running: true
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/lock/background.py"]
        stdout: SplitParser {
            onRead: output => {
                try {
                    var info = JSON.parse(output.trim());
                    theme.backgroundSource = info.path || "";
                    theme.backgroundIsVideo = info.video === true;
                } catch (e) {}
            }
        }
    }

    Process {
        running: true
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/lock/users.py"]
        stdout: SplitParser {
            onRead: output => {
                try {
                    var result = JSON.parse(output.trim());
                    if (result.users && result.users.length > 0)
                        theme.users = result.users;
                } catch (e) {}
            }
        }
    }
}
