pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    property var cfg: ({})
    property var themes: ({})

    function parseCfg(txt) {
        if (!txt) return;
        try { theme.cfg = JSON.parse(txt) || ({}); } catch (e) {}
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: theme.parseCfg(text())
        onTextChanged: theme.parseCfg(text())
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/themes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { theme.themes = JSON.parse(text()) || ({}); } catch (e) {}
        }
    }

    function num(section, key, def) {
        var s = theme.cfg[section];
        if (!s) return def;
        var v = s[key];
        return (typeof v === "number" && isFinite(v)) ? v : def;
    }

    readonly property string mode: {
        var t = theme.cfg.theme;
        var m = t ? t.mode : "";
        return (m === "light" || m === "glass") ? m : "dark";
    }
    readonly property bool light: theme.mode === "light"
    readonly property bool glass: theme.mode === "glass"

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

    readonly property color panelBg: theme.col("panelBg", "#f2101014")
    readonly property color panelBorder: theme.col("panelBorder", "#1cffffff")
    readonly property color card: theme.col("card", "#1a1a22")
    readonly property color cardHover: theme.col("cardHover", "#282836")
    readonly property color textPrimary: theme.col("textPrimary", "#f8fafc")
    readonly property color textSecondary: theme.col("textSecondary", "#a1a1aa")
    readonly property color divider: theme.col("divider", "#18ffffff")

    readonly property int panelWidth: theme.num("clipboard", "panelWidth", 420)
    readonly property int panelHeight: theme.num("clipboard", "panelHeight", 420)
    readonly property int radiusPanel: theme.num("clipboard", "radiusPanel", 16)
    readonly property int rowHeight: theme.num("clipboard", "rowHeight", 36)
    readonly property int rowCount: theme.num("clipboard", "rowCount", 10)
    readonly property int animMs: theme.num("clipboard", "animMs", 160)
}
