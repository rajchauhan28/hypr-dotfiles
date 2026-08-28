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
        path: Quickshell.env("HOME") + "/.config/quickshell/settings.json"
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
    // The hairline between stacked entries. Deliberately dimmer than
    // panelBorder: it divides one card, it does not outline two.
    readonly property color divider: "#18ffffff"

    readonly property color textPrimary: "#f8fafc"
    readonly property color textSecondary: "#a1a1aa"
    readonly property color textMuted: "#71717a"

    readonly property color accent: theme.col("accent", "#e4e4e7")
    readonly property color good: theme.col("good", "#86d9a3")
    readonly property color warn: theme.col("warn", "#e0c26b")
    readonly property color danger: theme.col("danger", "#e06b6b")

    readonly property int panelWidth: theme.num("notifications", "panelWidth", 380)
    // Must stay >= cornerFillet: the bottom scoop is drawn in the band below
    // the card, and a smaller margin runs it off the surface and clips it flat.
    readonly property int bottomMargin: Math.max(
        theme.num("notifications", "bottomMargin", 30), cornerFillet)
    readonly property int cardPadding: theme.num("notifications", "cardPadding", 14)
    readonly property int iconSize: theme.num("notifications", "iconSize", 34)
    readonly property int radiusPanel: theme.num("notifications", "radiusPanel", 18)
    readonly property int radiusSmall: theme.num("notifications", "radiusSmall", 10)
    readonly property int cornerFillet: theme.num("notifications", "cornerFillet", 22)
    readonly property int maxVisible: theme.num("notifications", "maxVisible", 5)
    readonly property int bodyMaxLines: theme.num("notifications", "bodyMaxLines", 4)

    // Seconds. Apps that pass expireTimeout -1 fall back to these.
    readonly property int timeoutLow: theme.num("notifications", "timeoutLow", 4)
    readonly property int timeoutNormal: theme.num("notifications", "timeoutNormal", 6)

    readonly property int animFast: 120
    readonly property int animNormal: 220
    readonly property int animPanel: 380
    readonly property int animSlide: 520
    readonly property var easeOutBack: Easing.OutBack
    readonly property var easeOutExpo: Easing.OutExpo
    readonly property var easeOutQuint: Easing.OutQuint
}
