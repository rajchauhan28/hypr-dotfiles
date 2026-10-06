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
    // The hairline between stacked entries. Deliberately dimmer than
    // panelBorder: it divides one card, it does not outline two.
    readonly property color divider: theme.col("divider", "#18ffffff")

    readonly property color textPrimary: theme.col("textPrimary", "#f8fafc")
    readonly property color textSecondary: theme.col("textSecondary", "#a1a1aa")
    readonly property color textMuted: theme.col("textMuted", "#71717a")

    readonly property color accent: theme.col("accent", "#e4e4e7")
    readonly property color onAccent: theme.col("onAccent", "#101014")
    readonly property color good: theme.col("good", "#86d9a3")
    readonly property color warn: theme.col("warn", "#e0c26b")
    readonly property color danger: theme.col("danger", "#e06b6b")

    readonly property int panelWidth: theme.num("notifications", "panelWidth", 380)
    // Must stay >= cornerFillet: the bottom scoop is drawn in the band below
    // the card, and a smaller margin runs it off the surface and clips it flat.
    readonly property int bottomMargin: Math.max(
        theme.num("notifications", "bottomMargin", 30), cornerFillet)
    readonly property int cardPadding: theme.num("notifications", "cardPadding", 14)
    readonly property int iconSize: theme.num("notifications", "iconSize", 34)
    readonly property int radiusPanel: theme.num("notifications", "radiusPanel", 18)
    readonly property int radiusSmall: theme.num("notifications", "radiusSmall", 10)
    readonly property int cornerFillet: theme.num("notifications", "cornerFillet", 22)
    readonly property int maxVisible: theme.num("notifications", "maxVisible", 5)
    readonly property int bodyMaxLines: theme.num("notifications", "bodyMaxLines", 4)

    // Seconds. Apps that pass expireTimeout -1 fall back to these.
    readonly property int timeoutLow: theme.num("notifications", "timeoutLow", 4)
    readonly property int timeoutNormal: theme.num("notifications", "timeoutNormal", 6)

    // How long a notification the SENDER marked critical stays up. 0 means
    // never expire, which is what the spec suggests and what this shell used
    // to do unconditionally -- but plenty of apps mark routine chatter
    // critical, and those were the ones piling up on screen until clicked.
    readonly property int timeoutCritical: theme.num("notifications", "timeoutCritical", 20)

    // Notifications whose app name, summary or body contains one of these
    // (case-insensitive substring) are treated as critical no matter what the
    // sender said, and stay until dismissed. This is the escape hatch for the
    // things that genuinely must not scroll past.
    readonly property var criticalKeywordDefaults: [
        "reboot",
        "restart required",
        "system upgrade",
        "system update",
        "security update",
        "updates available",
        "low battery",
        "battery critical",
        "disk full",
        "no space left",
        "authentication required",
        "backup failed"
    ]

    readonly property var criticalKeywords: {
        var s = theme.cfg["notifications"];
        var v = s ? s["criticalKeywords"] : undefined;
        // A malformed or missing list falls back rather than silently
        // disabling every keyword.
        return Array.isArray(v) ? v : theme.criticalKeywordDefaults;
    }

    // Notification center (Super+N) and its SQLite history.
    readonly property int historyMax: theme.num("notifications", "historyMax", 500)
    readonly property int centerWidth: theme.num("notifications", "centerWidth", 420)
    readonly property int centerMargin: theme.num("notifications", "centerMargin", 12)

    readonly property int animFast: 120
    readonly property int animNormal: 220
    readonly property int animPanel: 380
    readonly property int animSlide: 520
    readonly property var easeOutBack: Easing.OutBack
    readonly property var easeOutExpo: Easing.OutExpo
    readonly property var easeOutQuint: Easing.OutQuint
}
