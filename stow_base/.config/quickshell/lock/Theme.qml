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

    function col(key, def) {
        var p = theme.cfg.palette;
        if (!p) return def;
        var v = p[key];
        return (typeof v === "string" && v !== "") ? v : def;
    }

    readonly property color panelBg: theme.col("panelBg", "#f2101014")
    readonly property color accent: theme.col("accent", "#e4e4e7")
    readonly property color textPrimary: "#f8fafc"
    readonly property color textSecondary: "#a1a1aa"
    readonly property color textMuted: "#71717a"
    readonly property color danger: theme.col("danger", "#e06b6b")

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
