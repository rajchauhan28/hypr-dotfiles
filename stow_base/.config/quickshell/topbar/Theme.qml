pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    // Live overrides written by the settings app (qs -c settings). Every value
    // below keeps its literal default as the fallback, so a missing, empty or
    // half-written settings.json leaves the panel looking exactly as shipped.
    property var cfg: ({})
    property string osIcon: ""
    readonly property string username: Quickshell.env("USER") || "user"

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

    // Matches the Super+Tab overview palette.
    readonly property color panelBg: theme.col("panelBg", "#f2101014")
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

    readonly property color accent: theme.col("accent", "#e4e4e7")
    readonly property color onAccent: theme.col("onAccent", "#101014")
    readonly property color good: theme.col("good", "#86d9a3")
    readonly property color warn: theme.col("warn", "#e0c26b")
    readonly property color danger: theme.col("danger", "#e06b6b")

    // Topbar one-offs; each dark default is the literal it replaced.
    readonly property color onAccentText: theme.col("onAccentText", "#0a0a0f")
    readonly property color accentHover: theme.col("accentHover", "#ffffff")
    readonly property color onDanger: theme.col("onDanger", "#ffffff")
    readonly property color discHole: theme.col("discHole", "#0a0a0f")
    readonly property color artScrimTop: theme.col("artScrimTop", "#99101014")
    readonly property color artScrimBottom: theme.col("artScrimBottom", "#e6101014")
    // Text over the dashboard player's black art scrim: light in every mode.
    readonly property color scrimText: theme.col("scrimText", "#f8fafc")
    readonly property color scrimTextDim: theme.col("scrimTextDim", "#a1a1aa")

    // The dashboard identity card mirrors the lockscreen profile image.  An
    // empty setting means to use the detected distribution logo instead.
    readonly property string lockIcon: {
        var section = theme.cfg.lockscreen;
        return section && section.icon ? section.icon : "";
    }
    readonly property string profileIcon: lockIcon !== "" ? lockIcon : osIcon
    readonly property bool hasCustomProfileIcon: lockIcon !== ""

    readonly property int radiusPanel: theme.num("topbar", "radiusPanel", 20)
    readonly property int radiusCard: 16
    readonly property int radiusSmall: 10

    // Shared geometry so the hotspot and the panel agree.
    readonly property int hotspotHeight: theme.num("topbar", "hotspotHeight", 15)
    readonly property real hotspotWidthFraction: theme.num("topbar", "hotspotWidthFraction", 0.10)
    // 16:9 frame by default.
    readonly property int panelWidth: theme.num("topbar", "panelWidth", 1280)
    readonly property int panelHeight: theme.num("topbar", "panelHeight", 720)
    // The rail along the very top of the screen. It is NOT always visible: it
    // slides down when the pointer reaches the top edge, and clicking it opens
    // the dashboard, which grows out of it joined by concave fillets of
    // cornerFillet radius.
    readonly property int edgeLine: theme.num("topbar", "edgeLine", 5)
    readonly property int cornerFillet: theme.num("topbar", "cornerFillet", 30)
    readonly property int panelTopMargin: 0

    // Shared breathing room so every tab is spaced the same way.
    readonly property int gap: theme.num("topbar", "gap", 16)
    readonly property int cardPadding: theme.num("topbar", "cardPadding", 18)

    // Motion & Animation Design Tokens
    readonly property int animFast: 120
    readonly property int animNormal: 220
    readonly property int animSlow: 350
    readonly property int animPanel: 380

    readonly property int easeOutQuint: Easing.OutQuint
    readonly property int easeOutExpo: Easing.OutExpo
    readonly property int easeOutBack: Easing.OutBack
    readonly property int easeInOutCubic: Easing.InOutCubic

    Process {
        running: true
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/settings/system_info.py"]
        stdout: SplitParser {
            onRead: output => {
                try {
                    var info = JSON.parse(output.trim());
                    theme.osIcon = info.icon
                                   || Quickshell.iconPath(info.logoName || info.id, true);
                } catch (e) {}
            }
        }
    }

    // Glyph colour for a fill that is not a theme colour: the album-art
    // accent (pastel when art decoded, Theme.accent when it did not). Light
    // mode only -- dark and glass keep onAccentText, which is what they drew
    // before themes existed.
    function textOn(c) {
        if (!theme.light)
            return theme.onAccentText;
        var l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        return l > 0.45 ? "#0a0a0f" : "#fafafa";
    }

    // Colour ramp for load-style meters.
    function meterColor(pct) {
        if (pct >= 85)
            return theme.danger;
        if (pct >= 60)
            return theme.warn;
        return theme.accent;
    }
}
