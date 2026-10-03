pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    // Live overrides written by the settings app (qs -c settings). Every value
    // below keeps its literal default as the fallback, so a missing, empty or
    // half-written settings.json leaves the launcher looking exactly as
    // shipped. Same contract as the dock/topbar/sidepanel themes.
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

    // Same palette as every other panel.
    readonly property color panelBg: theme.col("panelBg", "#f2101014")
    readonly property color panelBorder: theme.col("panelBorder", "#1cffffff")

    // The shared card vocabulary the topbar and notifications already use.
    // The launcher used to invent its own bluish greys (#242430 / #2a2a38),
    // which is why it read as a foreign surface sitting on top of the shell.
    readonly property color card: theme.col("card", "#1a1a22")
    readonly property color cardAlt: theme.col("cardAlt", "#15151c")
    readonly property color cardHover: theme.col("cardHover", "#242430")
    readonly property color border: theme.col("border", "#14ffffff")
    readonly property color borderStrong: theme.col("borderStrong", "#28ffffff")
    // Divides rows inside one card, so it is softer than panelBorder, which
    // outlines the card itself.
    readonly property color divider: theme.col("divider", "#18ffffff")

    // Selection is derived from the accent rather than hardcoded, so setting a
    // coloured accent in the settings app tints the launcher too instead of
    // leaving a grey-blue highlight behind. Alphas are low: at full strength a
    // near-white accent would wash the row out.
    readonly property color rowSelected: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10)

    readonly property color textPrimary: theme.col("textPrimary", "#f8fafc")
    readonly property color textSecondary: theme.col("textSecondary", "#a1a1aa")
    readonly property color textMuted: theme.col("textMuted", "#71717a")
    readonly property color textFaint: theme.col("textFaint", "#3f3f46")

    readonly property color accent: theme.col("accent", "#e4e4e7")
    readonly property color onAccent: theme.col("onAccent", "#101014")
    readonly property color good: theme.col("good", "#86d9a3")
    readonly property color warn: theme.col("warn", "#e0c26b")
    readonly property color danger: theme.col("danger", "#e06b6b")

    // Centred card. Height is a ceiling, not a fixed size: the card shrinks to
    // its rows so a two-hit search does not leave a tall empty well.
    readonly property int panelWidth: theme.num("launcher", "panelWidth", 680)
    readonly property int maxListHeight: theme.num("launcher", "maxListHeight", 420)
    readonly property int rowHeight: theme.num("launcher", "rowHeight", 52)
    readonly property int iconSize: theme.num("launcher", "iconSize", 32)

    // Clipboard rows carry a real preview (screenshot, GIF, video thumbnail),
    // so they get a wider, taller slot than a bare icon needs. 16:10-ish keeps
    // typical screenshots from being cropped to uselessness.
    readonly property int clipRowHeight: theme.num("launcher", "clipRowHeight", 76)
    readonly property int clipPreviewWidth: theme.num("launcher", "clipPreviewWidth", 96)
    readonly property int clipPreviewHeight: theme.num("launcher", "clipPreviewHeight", 60)

    readonly property int radiusPanel: theme.num("launcher", "radiusPanel", 18)
    readonly property int radiusSmall: theme.num("launcher", "radiusSmall", 10)
    readonly property int cardPadding: theme.num("launcher", "cardPadding", 14)
    readonly property int searchHeight: theme.num("launcher", "searchHeight", 52)

    // The search field is a well inside the card, the way every input in the
    // settings app and the sidepanel is drawn, rather than bare text floating
    // on the panel background.
    readonly property int fieldHeight: theme.num("launcher", "fieldHeight", 44)
    readonly property int radiusField: theme.num("launcher", "radiusField", 12)
    readonly property int radiusChip: 7

    // How many results to build delegates for. The scorer ranks everything;
    // this only caps what gets instantiated. Matches cliphist's -max-items
    // (100, set in cliphist-text/image.service) so the whole retained
    // clipboard history is actually reachable in the panel.
    readonly property int maxResults: theme.num("launcher", "maxResults", 100)

    // Motion tokens, shared with the other panels.
    readonly property int animFast: 120
    readonly property int animNormal: 220
    readonly property int animPanel: 380

    readonly property int easeOutQuint: Easing.OutQuint
    readonly property int easeOutExpo: Easing.OutExpo
    readonly property int easeOutBack: Easing.OutBack
    readonly property int easeInOutCubic: Easing.InOutCubic
}
