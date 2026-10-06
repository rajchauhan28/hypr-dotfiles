pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    property var cfg: ({})
    property var themes: ({})

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { theme.cfg = JSON.parse(text()) || ({}); } catch (e) {}
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/themes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { theme.themes = JSON.parse(text()) || ({}); } catch (e) {}
        }
    }

    function num(key, def) {
        var s = theme.cfg["wallpaper"];
        var v = s ? s[key] : undefined;
        return (typeof v === "number" && isFinite(v)) ? v : def;
    }

    readonly property string mode: {
        var t = theme.cfg.theme;
        var m = t ? t.mode : "";
        return (m === "light" || m === "glass") ? m : "dark";
    }

    function col(key, def) {
        var sec = theme.mode === "light" ? "paletteLight" : theme.mode === "glass" ? "paletteGlass" : "palette";
        var p = theme.cfg[sec];
        if (p && typeof p[key] === "string" && p[key] !== "")
            return p[key];
        var t = theme.themes[theme.mode];
        if (t && typeof t[key] === "string" && t[key] !== "")
            return t[key];
        return def;
    }

    readonly property color accent: theme.col("accent", "#e4e4e7")

    // Card heights as a fraction of the screen height; widths follow from
    // the aspect ratios. skew is the horizontal lean per pixel of height.
    readonly property real currentHeight: theme.num("currentHeight", 0.36)
    readonly property real sideHeight: theme.num("sideHeight", 0.28)
    readonly property real currentAspect: theme.num("currentAspect", 1.25)
    readonly property real sideAspect: theme.num("sideAspect", 0.8)
    readonly property real skew: theme.num("skew", 0.22)
    readonly property int spacing: theme.num("spacing", 14)
    readonly property int animMs: theme.num("animMs", 240)
}
