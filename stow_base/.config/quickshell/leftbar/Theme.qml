pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    property var cfg: ({})

    function parseCfg(txt) {
        if (!txt) return;
        try {
            theme.cfg = JSON.parse(txt) || ({});
        } catch (e) {}
    }

    FileView {
        path: "/home/reign/.config/quickshell/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: theme.parseCfg(text())
        onTextChanged: theme.parseCfg(text())
    }

    function num(section, key, def) {
        var s = theme.cfg[section];
        if (!s) return def;
        var v = s[key];
        return (typeof v === "number" && isFinite(v)) ? v : def;
    }

    function col(key, def) {
        var p = theme.cfg.palette;
        if (!p) return def;
        var v = p[key];
        return (typeof v === "string" && v !== "") ? v : def;
    }

    readonly property color panelBg: theme.col("panelBg", "#f2101014")
    readonly property color panelBorder: "#1cffffff"
    readonly property color card: "#1a1a22"
    readonly property color cardHover: "#282836"
    readonly property color border: "#14ffffff"
    readonly property color borderStrong: "#30ffffff"

    readonly property color textPrimary: "#f8fafc"
    readonly property color textSecondary: "#a1a1aa"
    readonly property color textMuted: "#71717a"

    readonly property color accent: theme.col("accent", "#e4e4e7")
    readonly property color good: theme.col("good", "#86d9a3")
    readonly property color danger: theme.col("danger", "#ef4444")

    readonly property int barWidth: theme.num("leftbar", "barWidth", 54)
    readonly property int iconSlot: theme.num("leftbar", "iconSlot", 38)
    readonly property int barPadding: theme.num("leftbar", "barPadding", 10)
    readonly property int radiusPanel: theme.num("leftbar", "radiusPanel", 16)
    readonly property int radiusSmall: theme.num("leftbar", "radiusSmall", 10)
    readonly property int edgeLine: theme.num("leftbar", "edgeLine", 5)
    readonly property int cornerFillet: theme.num("leftbar", "cornerFillet", 20)

    readonly property int animFast: 120
    readonly property int animNormal: 220
    readonly property int animPanel: 380
    readonly property var easeOutBack: Easing.OutBack
    readonly property var easeOutExpo: Easing.OutExpo
    readonly property var easeOutQuint: Easing.OutQuint
}
