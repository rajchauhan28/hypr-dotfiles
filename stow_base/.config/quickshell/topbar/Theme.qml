pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    // Live overrides written by the settings app (qs -c settings). Every value
    // below keeps its literal default as the fallback, so a missing, empty or
    // half-written settings.json leaves the panel looking exactly as shipped.
    property var cfg: ({})
    property string osIcon: ""
    readonly property string username: Quickshell.env("USER") || "user"

    FileView {
        path: "/home/reign/.config/quickshell/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                theme.cfg = JSON.parse(text()) || ({});
            } catch (e) {
                // Keep the last good copy rather than snapping to defaults
                // while the settings app is mid-write.
            }
        }
    }

    function num(section, key, def) {
        var s = theme.cfg[section];
        if (!s)
            return def;
        var v = s[key];
        return (typeof v === "number" && isFinite(v)) ? v : def;
    }

    function col(key, def) {
        var p = theme.cfg.palette;
        if (!p)
            return def;
        var v = p[key];
        return (typeof v === "string" && v !== "") ? v : def;
    }

    // Matches the Super+Tab overview palette.
    readonly property color panelBg: theme.col("panelBg", "#f2101014")
    readonly property color panelBorder: "#1cffffff"
    readonly property color card: "#1a1a22"
    readonly property color cardAlt: "#15151c"
    readonly property color cardHover: "#242430"
    readonly property color border: "#14ffffff"
    readonly property color borderStrong: "#28ffffff"

    readonly property color textPrimary: "#f8fafc"
    readonly property color textSecondary: "#a1a1aa"
    readonly property color textMuted: "#71717a"
    readonly property color textFaint: "#3f3f46"

    readonly property color accent: theme.col("accent", "#e4e4e7")
    readonly property color good: theme.col("good", "#86d9a3")
    readonly property color warn: theme.col("warn", "#e0c26b")
    readonly property color danger: theme.col("danger", "#e06b6b")

    // The dashboard identity card mirrors the lockscreen profile image.  An
    // empty setting means to use the detected distribution logo instead.
    readonly property string lockIcon: {
        var section = theme.cfg.lockscreen;
        return section && section.icon ? section.icon : "";
    }
    readonly property string profileIcon: lockIcon !== "" ? lockIcon : osIcon
    readonly property bool hasCustomProfileIcon: lockIcon !== ""

    readonly property int radiusPanel: theme.num("topbar", "radiusPanel", 20)
    readonly property int radiusCard: 16
    readonly property int radiusSmall: 10

    // Shared geometry so the hotspot and the panel agree.
    readonly property int hotspotHeight: theme.num("topbar", "hotspotHeight", 15)
    readonly property real hotspotWidthFraction: theme.num("topbar", "hotspotWidthFraction", 0.10)
    // 16:9 frame by default.
    readonly property int panelWidth: theme.num("topbar", "panelWidth", 1280)
    readonly property int panelHeight: theme.num("topbar", "panelHeight", 720)
    // Always-visible rail along the very top of the screen. The panel grows
    // out of it, joined by concave fillets of cornerFillet radius.
    readonly property int edgeLine: theme.num("topbar", "edgeLine", 5)
    readonly property int cornerFillet: theme.num("topbar", "cornerFillet", 30)
    readonly property int panelTopMargin: 0

    // Shared breathing room so every tab is spaced the same way.
    readonly property int gap: theme.num("topbar", "gap", 16)
    readonly property int cardPadding: theme.num("topbar", "cardPadding", 18)

    // Motion & Animation Design Tokens
    readonly property int animFast: 120
    readonly property int animNormal: 220
    readonly property int animSlow: 350
    readonly property int animPanel: 380

    readonly property int easeOutQuint: Easing.OutQuint
    readonly property int easeOutExpo: Easing.OutExpo
    readonly property int easeOutBack: Easing.OutBack
    readonly property int easeInOutCubic: Easing.InOutCubic

    Process {
        running: true
        command: ["python3", "/home/reign/.config/quickshell/settings/system_info.py"]
        stdout: SplitParser {
            onRead: output => {
                try {
                    var info = JSON.parse(output.trim());
                    theme.osIcon = info.icon
                                   || Quickshell.iconPath(info.logoName || info.id, true);
                } catch (e) {}
            }
        }
    }

    // Colour ramp for load-style meters.
    function meterColor(pct) {
        if (pct >= 85)
            return theme.danger;
        if (pct >= 60)
            return theme.warn;
        return theme.accent;
    }
}
