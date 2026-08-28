pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    // Live overrides written by the settings app (qs -c settings). Every value
    // below keeps its literal default as the fallback, so a missing, empty or
    // half-written settings.json leaves the strip looking exactly as shipped.
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

    // Same palette as the topbar panel and the Super+Tab overview.
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

    readonly property int radiusPanel: theme.num("sidepanel", "radiusPanel", 16)
    readonly property int radiusSmall: 10

    // Trigger strip: a sliver down the right edge, vertically centred.
    readonly property int hotspotWidth: theme.num("sidepanel", "hotspotWidth", 15)
    readonly property real hotspotHeightFraction: theme.num("sidepanel", "hotspotHeightFraction", 0.10)

    // Icon-only strip. The body grows leftward out of the rail, so panelWidth
    // is what animates.
    readonly property int iconCount: 5
    readonly property int iconSlot: theme.num("sidepanel", "iconSlot", 48)
    readonly property int stripPadding: theme.num("sidepanel", "stripPadding", 8)
    readonly property int panelWidth: theme.num("sidepanel", "panelWidth", 50)
    readonly property int panelHeight: iconCount * iconSlot + stripPadding * 2

    // Room to the left of the strip for the scroll read-out. Painted but
    // deliberately outside the input mask, so it never eats a click.
    readonly property int osdWidth: theme.num("sidepanel", "osdWidth", 130)

    // Always-visible rail down the very right of the screen, joined to the
    // body by concave fillets of cornerFillet radius. The fillet cannot exceed
    // the body's width or the scoops would meet in the middle.
    readonly property int edgeLine: theme.num("sidepanel", "edgeLine", 5)
    readonly property int cornerFillet: theme.num("sidepanel", "cornerFillet", 20)

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

