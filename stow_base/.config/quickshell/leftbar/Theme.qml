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
    readonly property color panelBorder: theme.col("panelBorder", "#1cffffff")
    readonly property color card: theme.col("card", "#1a1a22")
    readonly property color cardHover: theme.col("cardHover", "#282836")
    readonly property color border: theme.col("border", "#14ffffff")
    readonly property color borderStrong: theme.col("borderStrong", "#30ffffff")

    readonly property color textPrimary: theme.col("textPrimary", "#f8fafc")
    readonly property color textSecondary: theme.col("textSecondary", "#a1a1aa")
    readonly property color textMuted: theme.col("textMuted", "#71717a")

    readonly property color accent: theme.col("accent", "#e4e4e7")
    readonly property color onAccent: theme.col("onAccent", "#101014")
    readonly property color good: theme.col("good", "#86d9a3")
    readonly property color danger: theme.col("danger", "#ef4444")
    readonly property color dangerWash: theme.col("dangerWash", Qt.rgba(0.93, 0.26, 0.26, 0.25))
    readonly property color tooltipBg: theme.col("tooltipBg", "#f2121218")

    readonly property int barWidth: theme.num("leftbar", "barWidth", 54)
    readonly property int iconSlot: theme.num("leftbar", "iconSlot", 38)
    readonly property int barPadding: theme.num("leftbar", "barPadding", 10)
    readonly property int radiusPanel: theme.num("leftbar", "radiusPanel", 16)
    readonly property int radiusSmall: theme.num("leftbar", "radiusSmall", 10)
    readonly property int edgeLine: theme.num("leftbar", "edgeLine", 5)
    readonly property int cornerFillet: theme.num("leftbar", "cornerFillet", 20)

    // Width held open beside the bar for the hover tooltip. It is a fixed
    // reserve rather than a fit-to-text size on purpose: resizing a layer
    // surface under a resting pointer makes the compositor re-send
    // pointer leave/enter, which flips the hover that produced the tooltip in
    // the first place and the panel oscillates. Long labels elide into it.
    readonly property int tooltipReserve: theme.num("leftbar", "tooltipReserve", 230)

    readonly property int animFast: 120
    readonly property int animNormal: 220
    readonly property int animPanel: 380
    readonly property var easeOutBack: Easing.OutBack
    readonly property var easeOutExpo: Easing.OutExpo
    readonly property var easeOutQuint: Easing.OutQuint
}
