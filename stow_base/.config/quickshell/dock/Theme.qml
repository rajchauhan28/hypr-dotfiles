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

    function col(key, def) {
        var p = theme.cfg.palette;
        if (!p)
            return def;
        var v = p[key];
        return (typeof v === "string" && v !== "") ? v : def;
    }

    // Same palette as the topbar panel, sidepanel and the Super+Tab overview.
    readonly property color panelBg: theme.col("panelBg", "#f2101014")
    readonly property color panelBorder: "#1cffffff"
    readonly property color cardHover: "#242430"

    readonly property color textPrimary: "#f8fafc"
    readonly property color textSecondary: "#a1a1aa"
    readonly property color textMuted: "#71717a"
    readonly property color textFaint: "#3f3f46"

    readonly property color accent: theme.col("accent", "#e4e4e7")
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

