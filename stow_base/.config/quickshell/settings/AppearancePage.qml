import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    spacing: Theme.gap

    Card {
        title: "ACCENT"
        subtitle: "Used for sliders, the play button, the visualiser and hover borders"
        section: "palette"
        keys: ["accent"]

        ColorRow {
            key: "accent"
            label: "Accent"
            presets: ["#e4e4e7", "#8ab4f8", "#c4a7e7", "#86d9a3", "#e0a06b", "#e08bb0", "#6bd5e0"]
        }
    }

    Card {
        title: "STATUS COLOURS"
        subtitle: "Meters, warnings and the destructive power buttons"
        section: "palette"
        keys: ["good", "warn", "danger"]

        ColorRow {
            key: "good"
            label: "Good"
            presets: ["#86d9a3", "#7ee787", "#5ac8a8", "#a3d977"]
        }
        ColorRow {
            key: "warn"
            label: "Warning"
            presets: ["#e0c26b", "#e3b341", "#e0a06b", "#d9a441"]
        }
        ColorRow {
            key: "danger"
            label: "Danger"
            presets: ["#e06b6b", "#f85149", "#e05252", "#d97777"]
        }
    }

    Card {
        title: "PANEL BACKGROUND"
        subtitle: "#aarrggbb — the leading pair is opacity, so 'f2' is ~95% opaque"
        section: "palette"
        keys: ["panelBg"]

        ColorRow {
            key: "panelBg"
            label: "Background"
            presets: ["#f2101014", "#d9101014", "#b3101014", "#f2141420", "#f20a0a0a"]
        }
    }

    Card {
        title: "WHERE THIS APPLIES"

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 11
            lineHeight: 1.3
            color: Theme.textSecondary
            text: "Changes are written to ~/.config/quickshell/settings.json and picked up "
                  + "live by the top panel, the dock and the side panel — nothing needs "
                  + "restarting. The Super+Tab overview keeps its own palette.\n\n"
                  + "Delete the file to go back to the built-in look; every panel carries "
                  + "the same defaults on its own."
        }
    }
}
