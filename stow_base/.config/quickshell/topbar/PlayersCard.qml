import QtQuick
import QtQuick.Layouts

// Every MPRIS player on the bus, so a paused Spotify and a playing YouTube tab
// are both visible and either can be made the one the transport controls drive.
ColumnLayout {
    id: pane

    spacing: 8

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: "SOURCES"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.2
            color: Theme.textMuted
        }
        Item { Layout.fillWidth: true }
        Text {
            text: MediaService.players.length
            font.pixelSize: 9
            color: Theme.textFaint
        }
    }

    Text {
        visible: MediaService.players.length === 0
        text: "No media players running"
        font.pixelSize: 11
        color: Theme.textFaint
    }

    Repeater {
        model: MediaService.players

        delegate: Rectangle {
            required property var modelData

            readonly property bool current: MediaService.player === modelData
            // A manual pick is worth showing: it explains why a paused player is
            // the one the transport is driving.
            readonly property bool pinned: MediaService.preferredId === modelData.dbusName

            Layout.fillWidth: true
            implicitHeight: 40
            radius: Theme.radiusSmall
            color: rowMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
            border.color: current ? MediaService.accent : Theme.border
            border.width: current ? 2 : 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 9

                Text {
                    text: modelData.isPlaying ? "󰐊" : "󰏤"
                    font.pixelSize: 13
                    color: modelData.isPlaying ? MediaService.accent : Theme.textMuted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: MediaService.playerLabel(modelData)
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: modelData.trackTitle || "—"
                        font.pixelSize: 9
                        color: Theme.textMuted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Text {
                    visible: pinned
                    text: "󰐃"
                    font.pixelSize: 11
                    color: Theme.textSecondary
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Clicking the pinned player unpins it, so there is a way back
                // to "follow whatever is playing" without restarting the panel.
                onClicked: MediaService.selectPlayer(pinned ? "" : modelData.dbusName)
            }
        }
    }

    Item { Layout.fillHeight: true }
}
