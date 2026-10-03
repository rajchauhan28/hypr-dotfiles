pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A Singleton since the light/dark/glass themes: before that this was a plain
// QtObject nothing instantiated, so every Theme.x here read undefined and the
// overview drew only its own literals.
Singleton {
    id: theme

    property var cfg: ({})
    property var themes: ({})

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

    // The overview keeps its own darker dark palette (the literals below), so
    // only the light and glass modes take user/theme colours.
    function col(key, def) {
        if (theme.mode === "dark")
            return def;
        var sec = theme.light ? "paletteLight" : "paletteGlass";
        var p = theme.cfg[sec];
        if (p && typeof p[key] === "string" && p[key] !== "")
            return p[key];
        var t = theme.themes[theme.mode];
        if (t && typeof t[key] === "string" && t[key] !== "")
            return t[key];
        return def;
    }

    function ink(a) {
        return theme.light ? Qt.rgba(0, 0, 0, a) : Qt.rgba(1, 1, 1, a);
    }

    // Pure stealth shades of black & dark charcoal (No yellow, no bright colors)
    readonly property color background: theme.col("overviewBg", "#d408080c")
    readonly property color cardBackground: theme.col("overviewCard", "#121216")
    readonly property color cardHover: theme.col("cardHover", "#1c1c24")
    readonly property color activeWorkspaceBg: theme.col("overviewActive", "#22222c")
    readonly property color activeBorder: theme.col("activeBorder", "#50ffffff")
    readonly property color border: theme.col("border", "#14ffffff")
    readonly property color borderHover: theme.col("borderHover", "#30ffffff")
    readonly property color textPrimary: theme.col("textPrimary", "#f8fafc")
    readonly property color textSecondary: theme.col("textSecondary", "#a1a1aa")
    readonly property color textMuted: theme.col("textMuted", "#71717a")
    readonly property color accent: theme.col("accent", "#e4e4e7")
    readonly property color danger: theme.col("danger", "#ef4444")

    // One-off overview chrome (the modal, the mini-map window tiles, ...).
    readonly property color overviewPanel: theme.col("overviewPanel", "#0a0a0f")
    readonly property color overviewDropTarget: theme.col("overviewDropTarget", "#2a2a35")
    readonly property color overviewWindow: theme.col("overviewWindow", "#1a1a22")
    readonly property color overviewWindowHover: theme.col("overviewWindowHover", "#282836")
    readonly property color overviewWindowDrag: theme.col("overviewWindowDrag", "#303040")
    readonly property color textStrong: theme.col("textStrong", "#ffffff")
    readonly property color textFaint: theme.col("textFaint", "#52525b")
    readonly property color onDanger: theme.col("onDanger", "#ffffff")

    readonly property int radiusLarge: 20
    readonly property int radiusMedium: 14
    readonly property int radiusSmall: 10

    // Motion & Animation Design Tokens
    readonly property int animFast: 120
    readonly property int animNormal: 220
    readonly property int animSlow: 350
    readonly property int animPanel: 380

    readonly property int easeOutQuint: Easing.OutQuint
    readonly property int easeOutExpo: Easing.OutExpo
    readonly property int easeOutBack: Easing.OutBack
    readonly property int easeInOutCubic: Easing.InOutCubic
}
