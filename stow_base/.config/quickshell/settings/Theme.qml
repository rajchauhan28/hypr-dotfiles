pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Same palette as the topbar, dock, sidepanel and the Super+Tab overview --
// except the accent colours, which come from Config so the app previews an
// accent change on itself the moment you pick one.
Singleton {
    id: theme

    // ---- Light / dark / glass ------------------------------------------
    // The mode comes from Config (settings.json), so picking a theme repaints
    // this window on the same frame the panels see the write. The light and
    // glass palettes come from ../themes.json; dark is the literals below.
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

    readonly property string mode: Config.themeMode
    readonly property bool light: theme.mode === "light"
    readonly property bool glass: theme.mode === "glass"

    function col(key, def) {
        var t = theme.themes[theme.mode];
        if (t && typeof t[key] === "string" && t[key] !== "")
            return t[key];
        return def;
    }

    function ink(a) {
        return theme.light ? Qt.rgba(0, 0, 0, a) : Qt.rgba(1, 1, 1, a);
    }

    readonly property color windowBg: theme.col("windowBg", "#0c0c11")
    readonly property color panelBg: Config.get(Config.paletteSection, "panelBg")
    readonly property color panelBorder: theme.col("panelBorder", "#1cffffff")
    readonly property color card: theme.col("card", "#1a1a22")
    readonly property color cardAlt: theme.col("cardAlt", "#15151c")
    readonly property color cardHover: theme.col("cardHover", "#242430")
    readonly property color border: theme.col("border", "#14ffffff")
    readonly property color borderStrong: theme.col("borderStrong", "#28ffffff")

    readonly property color textPrimary: theme.col("textPrimary", "#f8fafc")
    readonly property color textSecondary: theme.col("textSecondary", "#a1a1aa")
    readonly property color textMuted: theme.col("textMuted", "#71717a")
    readonly property color textFaint: theme.col("textFaint", "#3f3f46")

    readonly property color accent: Config.get(Config.paletteSection, "accent")
    readonly property color onAccent: theme.col("onAccent", "#101014")
    readonly property color onAccentDeep: theme.col("onAccentDeep", "#0a0a0f")
    readonly property color avatarBg: theme.col("avatarBg", "#18181d")
    readonly property color good: Config.get(Config.paletteSection, "good")
    readonly property color warn: Config.get(Config.paletteSection, "warn")
    readonly property color danger: Config.get(Config.paletteSection, "danger")

    readonly property int radiusPanel: 20
    readonly property int radiusCard: 16
    readonly property int radiusSmall: 10

    readonly property int gap: 14
    readonly property int cardPadding: 16
}
