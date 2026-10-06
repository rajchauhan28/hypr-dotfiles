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
    readonly property color textPrimary: theme.col("textPrimary", "#f8fafc")
    readonly property color accent: theme.col("accent", "#e4e4e7")
    readonly property color warn: theme.col("warn", "#e0c26b")
    readonly property color trackBg: Qt.rgba(1, 1, 1, 0.12)

    // The osd section is new. panelWidth here is the whole pill width; the
    // existing settings.json key osdWidth is the sidepanel's own gutter and
    // deliberately not reused.
    readonly property int panelWidth: theme.num("osd", "panelWidth", 280)
    readonly property int panelHeight: theme.num("osd", "panelHeight", 56)
    readonly property int bottomMargin: theme.num("osd", "bottomMargin", 80)
    readonly property int radiusPanel: theme.num("osd", "radiusPanel", 14)
    readonly property int iconSize: theme.num("osd", "iconSize", 22)
    readonly property int trackHeight: theme.num("osd", "trackHeight", 6)
    readonly property int visibleMs: theme.num("osd", "visibleMs", 1500)
    readonly property int animMs: theme.num("osd", "animMs", 180)
}
