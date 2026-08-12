pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    readonly property color panelBg: "#f2101014"
    readonly property color panelBorder: "#1cffffff"
    readonly property color card: "#1a1a22"
    readonly property color cardHover: "#282836"
    readonly property color border: "#14ffffff"
    readonly property color borderStrong: "#30ffffff"

    readonly property color textPrimary: "#f8fafc"
    readonly property color textSecondary: "#a1a1aa"
    readonly property color textMuted: "#71717a"

    readonly property color accent: "#e4e4e7"
    readonly property color good: "#86d9a3"
    readonly property color danger: "#ef4444"

    readonly property int barWidth: 54
    readonly property int iconSlot: 44
    readonly property int radiusPanel: 16
    readonly property int radiusSmall: 10

    readonly property int animFast: 120
    readonly property int animNormal: 220
    readonly property var easeOutBack: Easing.OutBack
    readonly property var easeOutQuint: Easing.OutQuint
}
