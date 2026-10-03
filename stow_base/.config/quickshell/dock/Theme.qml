pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    // Live overrides written by the settings app (qs -c settings). Every value
    // below keeps its literal default as the fallback, so a missing, empty or
    // half-written settings.json leaves the dock looking exactly as shipped.
    property var cfg: ({})

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/settings.json"
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

    // Same palette as the topbar panel, sidepanel and the Super+Tab overview.
    readonly property color panelBg: theme.col("panelBg", "#f2101014")
    readonly property color panelBorder: theme.col("panelBorder", "#1cffffff")
    readonly property color cardHover: theme.col("cardHover", "#242430")
    readonly property color previewBg: theme.col("previewBg", "#0c0c10")

    readonly property color textPrimary: theme.col("textPrimary", "#f8fafc")
    readonly property color textSecondary: theme.col("textSecondary", "#a1a1aa")
    readonly property color textMuted: theme.col("textMuted", "#71717a")
    readonly property color textFaint: theme.col("textFaint", "#3f3f46")

    readonly property color accent: theme.col("accent", "#e4e4e7")
    readonly property color onAccent: theme.col("onAccent", "#101014")
    readonly property color good: theme.col("good", "#86d9a3")
    readonly property color warn: theme.col("warn", "#e0c26b")
    readonly property color danger: theme.col("danger", "#e06b6b")

    readonly property int radiusPanel: theme.num("dock", "radiusPanel", 16)
    readonly property int radiusSmall: 10

    // Trigger strip: a sliver along the bottom edge, horizontally centred.
    readonly property int hotspotHeight: theme.num("dock", "hotspotHeight", 15)
    readonly property real hotspotWidthFraction: theme.num("dock", "hotspotWidthFraction", 0.25)

    // Dock body. Width is dynamic (pinned + running apps), so shell.qml
    // computes it from the model; only the fixed metrics live here.
    readonly property int iconSlot: theme.num("dock", "iconSlot", 52)
    readonly property int iconSize: theme.num("dock", "iconSize", 34)
    readonly property int dockPadding: theme.num("dock", "dockPadding", 10)
    readonly property int separatorWidth: 11
    readonly property int panelHeight: iconSlot + dockPadding * 2

    // Room above the body for the hover tooltip. Painted but outside the
    // input mask, so it never eats a click.
    readonly property int tooltipArea: 36

    // Live window previews, shown above the tooltip band on hover.
    readonly property int previewTileW: theme.num("dock", "previewTileW", 176)
    readonly property int previewTileH: theme.num("dock", "previewTileH", 110)
    readonly property int previewPadding: 10
    readonly property int previewSpacing: 8
    readonly property int previewLabel: 15
    readonly property int previewMaxTiles: theme.num("dock", "previewMaxTiles", 5)
    readonly property int previewCardH: previewTileH + previewLabel + previewPadding * 2
    // Reserve a little more than the card so the pop-up animation has room.
    readonly property int previewArea: previewCardH + 10

    // Always-visible rail along the very bottom of the screen, joined to the
    // body by concave fillets of cornerFillet radius.
    readonly property int edgeLine: theme.num("dock", "edgeLine", 5)
    readonly property int cornerFillet: theme.num("dock", "cornerFillet", 20)

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

