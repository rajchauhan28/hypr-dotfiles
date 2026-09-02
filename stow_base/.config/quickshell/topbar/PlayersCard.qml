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

    // Scrolls once there are more than maxVisibleRows players. Below that the
    // list is exactly as tall as its contents, so the card does not reserve a
    // fixed well of empty space for players that are not running.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: sourceList.height
        visible: MediaService.players.length > 0

        ListView {
            id: sourceList

            readonly property int rowHeight: 40
            readonly property int rowSpacing: 8
            readonly property int maxVisibleRows: 4
            readonly property int maxHeight: maxVisibleRows * rowHeight
                                             + (maxVisibleRows - 1) * rowSpacing

            width: parent.width
            height: Math.min(contentHeight, maxHeight)
            spacing: rowSpacing
            clip: true
            model: MediaService.players
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
            required property var modelData

            readonly property bool current: MediaService.player === modelData
            // A manual pick is worth showing: it explains why a paused player is
            // the one the transport is driving.
            readonly property bool pinned: MediaService.preferredId === modelData.dbusName

            width: sourceList.width
            implicitHeight: sourceList.rowHeight
            height: implicitHeight
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

        // Slim scroll indicator, drawn rather than pulled from QtQuick.Controls
        // to match the rest of the shell. Only appears once the list actually
        // overflows.
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 1
            width: 3
            radius: 1.5
            color: Theme.textFaint
            visible: sourceList.contentHeight > sourceList.height

            height: sourceList.height * (sourceList.height / sourceList.contentHeight)
            y: sourceList.contentHeight > 0
               ? sourceList.contentY / sourceList.contentHeight * sourceList.height
               : 0
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        implicitHeight: 1
        color: Theme.border
    }

    // ---- Recently played --------------------------------------------------
    // Not a queue: nothing on the bus exposes one (see MediaService.history).
    // This is what actually played, newest first.
    RowLayout {
        Layout.fillWidth: true

        Text {
            text: "RECENTLY PLAYED"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.2
            color: Theme.textMuted
        }

        Item { Layout.fillWidth: true }

        Text {
            visible: MediaService.history.length > 0
            text: "clear"
            font.pixelSize: 9
            color: clearMouse.containsMouse ? Theme.danger : Theme.textFaint
            Behavior on color { ColorAnimation { duration: 120 } }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: MediaService.clearHistory()
            }
        }
    }

    Text {
        visible: MediaService.history.length === 0
        text: "Nothing played yet"
        font.pixelSize: 11
        color: Theme.textFaint
    }

    ListView {
        id: historyList

        // Ticks so the relative timestamps age without needing a track change
        // to repaint them.
        property double nowMs: Date.now()
        Timer {
            interval: 30000
            repeat: true
            running: historyList.visible
            onTriggered: historyList.nowMs = Date.now()
        }

        function ago(ms) {
            var mins = Math.floor((historyList.nowMs - ms) / 60000);
            if (mins < 1)
                return "now";
            if (mins < 60)
                return mins + "m";
            var hrs = Math.floor(mins / 60);
            if (hrs < 24)
                return hrs + "h";
            return Math.floor(hrs / 24) + "d";
        }

        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: MediaService.history.length > 0
        clip: true
        spacing: 2
        model: MediaService.history
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: histRow

            required property var modelData

            // Only rows whose player is still running can do anything on
            // click, so the rest must not pretend to be buttons.
            readonly property bool resumable: MediaService.playerAlive(modelData.playerId)

            width: historyList.width
            implicitHeight: 34
            height: implicitHeight
            radius: Theme.radiusSmall
            color: histMouse.containsMouse && resumable ? Theme.cardHover : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: histRow.modelData.title || "\u2014"
                        font.pixelSize: 10
                        color: histRow.resumable ? Theme.textSecondary : Theme.textMuted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: (histRow.modelData.artist || "")
                              + (histRow.modelData.player
                                 ? "  \u00b7  " + histRow.modelData.player : "")
                        font.pixelSize: 9
                        color: Theme.textFaint
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Text {
                    text: historyList.ago(histRow.modelData.at || 0)
                    font.pixelSize: 9
                    color: Theme.textFaint
                }
            }

            MouseArea {
                id: histMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: histRow.resumable ? Qt.PointingHandCursor : Qt.ArrowCursor
                // The most a shell can do from outside is put the transport
                // back on the player that track came from; it cannot make
                // Spotify or a browser tab seek to an old song.
                onClicked: {
                    if (histRow.resumable)
                        MediaService.selectPlayer(histRow.modelData.playerId);
                }
            }
        }
    }
}
