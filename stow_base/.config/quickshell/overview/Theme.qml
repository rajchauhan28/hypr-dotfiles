import QtQuick

QtObject {
    id: theme

    // Pure stealth shades of black & dark charcoal (No yellow, no bright colors)
    readonly property color background: "#d408080c"
    readonly property color cardBackground: "#121216"
    readonly property color cardHover: "#1c1c24"
    readonly property color activeWorkspaceBg: "#22222c"
    readonly property color activeBorder: "#50ffffff"
    readonly property color border: "#14ffffff"
    readonly property color borderHover: "#30ffffff"
    readonly property color textPrimary: "#f8fafc"
    readonly property color textSecondary: "#a1a1aa"
    readonly property color textMuted: "#71717a"
    readonly property color accent: "#e4e4e7"
    readonly property color danger: "#ef4444"

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

