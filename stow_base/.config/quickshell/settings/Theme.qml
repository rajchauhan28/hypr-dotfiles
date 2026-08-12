pragma Singleton

import QtQuick
import Quickshell

// Same palette as the topbar, dock, sidepanel and the Super+Tab overview --
// except the accent colours, which come from Config so the app previews an
// accent change on itself the moment you pick one.
Singleton {
    id: theme

    readonly property color windowBg: "#0c0c11"
    readonly property color panelBg: "#f2101014"
    readonly property color panelBorder: "#1cffffff"
    readonly property color card: "#1a1a22"
    readonly property color cardAlt: "#15151c"
    readonly property color cardHover: "#242430"
    readonly property color border: "#14ffffff"
    readonly property color borderStrong: "#28ffffff"

    readonly property color textPrimary: "#f8fafc"
    readonly property color textSecondary: "#a1a1aa"
    readonly property color textMuted: "#71717a"
    readonly property color textFaint: "#3f3f46"

    readonly property color accent: Config.get("palette", "accent")
    readonly property color good: Config.get("palette", "good")
    readonly property color warn: Config.get("palette", "warn")
    readonly property color danger: Config.get("palette", "danger")

    readonly property int radiusPanel: 20
    readonly property int radiusCard: 16
    readonly property int radiusSmall: 10

    readonly property int gap: 14
    readonly property int cardPadding: 16
}
