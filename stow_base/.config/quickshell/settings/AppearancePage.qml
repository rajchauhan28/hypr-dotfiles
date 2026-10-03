import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    spacing: Theme.gap

    readonly property string modeName: Config.themeMode === "light" ? "light"
                                     : Config.themeMode === "glass" ? "glass" : "dark"

    Card {
        title: "THEME"
        subtitle: "Every panel, the lock screen, the Super+Tab overview and this window"

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: [
                    { mode: "light", label: "Light", hint: "Bright panels, dark text" },
                    { mode: "dark", label: "Dark", hint: "The original look" },
                    { mode: "glass", label: "Glass", hint: "Liquid glass (hyprglass)" }
                ]

                delegate: Rectangle {
                    id: tile

                    required property var modelData
                    readonly property bool active: Config.themeMode === tile.modelData.mode

                    Layout.fillWidth: true
                    implicitHeight: 118
                    radius: Theme.radiusSmall + 2
                    color: tileMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                    border.width: tile.active ? 2 : 1
                    border.color: tile.active ? Theme.accent : Theme.border

                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    // A miniature of the mode: a desktop strip with a panel on
                    // it, drawn in that mode's own colours rather than the
                    // current theme's, so all three read correctly side by side.
                    Rectangle {
                        id: preview
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        height: 64
                        radius: Theme.radiusSmall
                        clip: true
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: tile.modelData.mode === "light" ? "#c9d6e8" : tile.modelData.mode === "glass" ? "#3a6ea5" : "#1c1c26" }
                            GradientStop { position: 1.0; color: tile.modelData.mode === "light" ? "#e9dfd3" : tile.modelData.mode === "glass" ? "#c0567f" : "#2a2a36" }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.62
                            height: 34
                            radius: 9
                            color: tile.modelData.mode === "light" ? "#f2f6f6f8"
                                 : tile.modelData.mode === "glass" ? "#40ffffff" : "#f2101014"
                            border.width: 1
                            border.color: tile.modelData.mode === "light" ? "#1f000000"
                                        : tile.modelData.mode === "glass" ? "#99ffffff" : "#1cffffff"

                            // Glass: a bright top sheen, the cheapest honest hint
                            // of what the compositor will draw.
                            Rectangle {
                                visible: tile.modelData.mode === "glass"
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 1
                                height: parent.height * 0.45
                                radius: 8
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#59ffffff" }
                                    GradientStop { position: 1.0; color: "#00ffffff" }
                                }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: 3
                                        color: tile.modelData.mode === "light" ? "#3f3f46" : "#e4e4e7"
                                        opacity: index === 0 ? 1.0 : 0.45
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: preview.bottom
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 7
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: tile.modelData.label
                                font.pixelSize: 12
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                visible: tile.active
                                text: "󰄬"
                                font.pixelSize: 13
                                color: Theme.accent
                            }
                        }
                        Text {
                            text: tile.modelData.hint
                            font.pixelSize: 10
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.setThemeMode(tile.modelData.mode)
                    }
                }
            }
        }
    }

    Card {
        title: "ACCENT"
        subtitle: "Used for sliders, the play button, the visualiser and hover borders -- " + page.modeName + " theme"
        section: Config.paletteSection
        keys: ["accent"]

        ColorRow {
            key: "accent"
            label: "Accent"
            presets: ["#e4e4e7", "#8ab4f8", "#c4a7e7", "#86d9a3", "#e0a06b", "#e08bb0", "#6bd5e0"]
        }
    }

    Card {
        title: "STATUS COLOURS"
        subtitle: "Meters, warnings and the destructive power buttons -- " + page.modeName + " theme"
        section: Config.paletteSection
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
        subtitle: "#aarrggbb — the leading pair is opacity, so 'f2' is ~95% opaque -- " + page.modeName + " theme"
        section: Config.paletteSection
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
                  + "live by every panel — nothing needs restarting. Each theme keeps its own "
                  + "colours, so the cards above edit the " + page.modeName + " theme only; the "
                  + "light and glass palettes themselves live in ~/.config/quickshell/themes.json.\n\n"
                  + "Glass needs the hyprglass Hyprland plugin for the frosting and refraction "
                  + "(~/.config/hypr/glass.lua; rebuild it with ~/.config/hypr/build-hyprglass.sh "
                  + "after a Hyprland update). Without it, glass is a very translucent dark theme."
        }
    }
}
