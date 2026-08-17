import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// The popup shell that replaced swaync. Every knob here is read live by
// notifications/Theme.qml, so a drag reshapes the card already on screen.
ColumnLayout {
    id: page

    spacing: Theme.gap

    Card {
        title: "POPUP SHAPE"
        subtitle: "One card welded to the right screen edge"
        section: "notifications"
        keys: ["panelWidth", "topMargin", "radiusPanel", "cornerFillet"]

        SliderRow { section: "notifications"; key: "panelWidth"; label: "Card width"; from: 260; to: 560; step: 4; suffix: " px" }
        SliderRow { section: "notifications"; key: "topMargin"; label: "Distance from top"; from: 0; to: 160; suffix: " px" }
        SliderRow { section: "notifications"; key: "radiusPanel"; label: "Corner radius"; from: 0; to: 36; suffix: " px" }
        SliderRow { section: "notifications"; key: "cornerFillet"; label: "Edge fillet"; from: 0; to: 48; suffix: " px" }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            visible: Config.get("notifications", "topMargin")
                     < Config.get("notifications", "cornerFillet")
            text: "Distance from top is below the fillet size, so the shell clamps it — "
                  + "the top scoop is drawn above the card and would otherwise clip flat."
            font.pixelSize: 9
            lineHeight: 1.35
            color: Theme.warn
            wrapMode: Text.WordWrap
        }
    }

    Card {
        title: "CONTENT"
        subtitle: "Inside one entry"
        section: "notifications"
        keys: ["cardPadding", "iconSize", "radiusSmall", "bodyMaxLines"]

        SliderRow { section: "notifications"; key: "cardPadding"; label: "Padding"; from: 4; to: 28; suffix: " px" }
        SliderRow { section: "notifications"; key: "iconSize"; label: "App icon size"; from: 16; to: 64; suffix: " px" }
        SliderRow { section: "notifications"; key: "radiusSmall"; label: "Icon / button radius"; from: 0; to: 20; suffix: " px" }
        SliderRow { section: "notifications"; key: "bodyMaxLines"; label: "Body lines"; from: 1; to: 12 }
    }

    Card {
        title: "BEHAVIOUR"
        subtitle: "Critical notifications never time out"
        section: "notifications"
        keys: ["maxVisible", "timeoutLow", "timeoutNormal"]

        SliderRow { section: "notifications"; key: "maxVisible"; label: "Max on screen"; from: 1; to: 10 }
        SliderRow { section: "notifications"; key: "timeoutNormal"; label: "Normal timeout"; from: 1; to: 30; suffix: " s" }
        SliderRow { section: "notifications"; key: "timeoutLow"; label: "Low timeout"; from: 1; to: 30; suffix: " s" }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: "An app that asks for its own timeout gets it; these apply when it doesn't."
            font.pixelSize: 9
            color: Theme.textFaint
            wrapMode: Text.WordWrap
        }
    }

    Card {
        title: "TEST"
        subtitle: "Send a notification through the running shell"

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { label: "Normal", urgency: "normal" },
                    { label: "Low", urgency: "low" },
                    { label: "Critical", urgency: "critical" }
                ]

                delegate: Rectangle {
                    required property var modelData

                    implicitWidth: 92
                    implicitHeight: 28
                    radius: Theme.radiusSmall
                    color: sendMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                    border.color: Theme.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 11
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: sendMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached([
                            "notify-send",
                            "-u", modelData.urgency,
                            "-a", "Shell Settings",
                            modelData.label + " notification",
                            "This is what a " + modelData.urgency
                              + " notification looks like with the current settings."
                        ])
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: 92
                implicitHeight: 28
                radius: Theme.radiusSmall
                color: clearMouse.containsMouse ? Theme.cardHover : "transparent"
                border.color: Theme.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Dismiss all"
                    font.pixelSize: 11
                    color: clearMouse.containsMouse ? Theme.danger : Theme.textMuted
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached([
                        "qs", "-c", "notifications", "ipc", "call", "notifications", "dismissAll"
                    ])
                }
            }
        }
    }
}
