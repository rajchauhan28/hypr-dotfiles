import QtQuick
import QtQuick.Layouts

Item {
    id: tab

    RowLayout {
        anchors.fill: parent
        spacing: Theme.gap

        // The 16:9 frame gives enough height for the stacked player again,
        // so this reuses MediaPane instead of duplicating a flat variant.
        Card {
            Layout.preferredWidth: 420
            Layout.fillHeight: true
            // clip so the blurred backdrop stops at the card's rounded corners.
            clip: true

            ArtBackdrop { anchors.fill: parent }

            MediaPane {
                anchors.fill: parent
                anchors.margins: Theme.cardPadding
                compact: false
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.gap

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.gap

                Card {
                    Layout.preferredWidth: 240
                    Layout.fillHeight: true

                    PlayersCard {
                        anchors.fill: parent
                        anchors.margins: Theme.cardPadding
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.cardPadding
                        spacing: 14

                        Text {
                            text: "OUTPUT"
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                            color: Theme.textMuted
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.gap

                            Rectangle {
                                implicitWidth: 40
                                implicitHeight: 40
                                radius: 20
                                color: muteMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                                border.color: Theme.border
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: MediaService.muted ? "󰝟"
                                                             : (MediaService.volume > 50 ? "󰕾"
                                                             : (MediaService.volume > 0 ? "󰖀" : "󰕿"))
                                    font.pixelSize: 18
                                    color: MediaService.muted ? Theme.danger : Theme.textPrimary
                                }

                                MouseArea {
                                    id: muteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: MediaService.toggleMute()
                                }
                            }

                            // Click-and-drag volume track
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 40

                                Rectangle {
                                    id: track
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 8
                                    radius: 4
                                    color: Theme.cardAlt
                                    border.color: Theme.border
                                    border.width: 1

                                    Rectangle {
                                        width: Math.max(0, Math.min(1, MediaService.volume / 100.0)) * (parent.width - 2)
                                        height: parent.height - 2
                                        x: 1
                                        y: 1
                                        radius: 4
                                        color: MediaService.muted ? Theme.textFaint : Theme.accent
                                        Behavior on width { NumberAnimation { duration: 120 } }
                                    }
                                }

                                Rectangle {
                                    id: knob
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: Theme.textPrimary
                                    border.color: Theme.panelBg
                                    border.width: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.max(0, Math.min(1, MediaService.volume / 100.0)) * (track.width - width)
                                    Behavior on x { NumberAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => MediaService.setVolume(mouse.x / width * 100)
                                    onPositionChanged: mouse => {
                                        if (pressed)
                                            MediaService.setVolume(mouse.x / width * 100);
                                    }
                                    onWheel: wheel => {
                                        MediaService.setVolume(MediaService.volume + (wheel.angleDelta.y > 0 ? 5 : -5));
                                    }
                                }
                            }

                            Text {
                                text: MediaService.volume + "%"
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                                Layout.minimumWidth: 44
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Theme.border
                        }

                        Text {
                            text: "TRACK"
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                            color: Theme.textMuted
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 7

                            Repeater {
                                // Flattened to key, value, key, value… so the two-column
                                // grid lays each pair out on its own row.
                                model: [
                                    "Title", MediaService.hasPlayer ? MediaService.title : "—",
                                    "Artist", MediaService.hasPlayer ? MediaService.artist : "—",
                                    "Album", MediaService.album !== "" ? MediaService.album : "—",
                                    "State", MediaService.hasPlayer ? MediaService.status : "No player"
                                ]
                                delegate: Text {
                                    readonly property bool isKey: index % 2 === 0
                                    Layout.fillWidth: !isKey
                                    Layout.minimumWidth: isKey ? 52 : 0
                                    text: modelData
                                    font.pixelSize: 11
                                    font.bold: isKey
                                    color: isKey ? Theme.textMuted : Theme.textPrimary
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
}
