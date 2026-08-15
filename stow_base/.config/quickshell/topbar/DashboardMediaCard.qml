import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// Compact dashboard-only player.  The full Media tab deliberately keeps the
// richer MediaPane layout.
ColumnLayout {
    id: player

    spacing: 8

    Item {
        id: artworkFrame

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 104

        Rectangle {
            id: artworkMaskShape
            anchors.fill: parent
            radius: 14
            color: "white"
        }

        ShaderEffectSource {
            id: artworkMask
            sourceItem: artworkMaskShape
            hideSource: true
            visible: false
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: artworkMask
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.cardAlt
            }

            Image {
                id: artwork
                anchors.fill: parent
                source: MediaService.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                visible: artwork.status !== Image.Ready
                color: Theme.cardAlt

                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    font.pixelSize: 42
                    color: Theme.textFaint
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.min(58, parent.height * 0.42)
                gradient: Gradient {
                    GradientStop { position: 0; color: "#00000000" }
                    GradientStop { position: 1; color: "#d8000000" }
                }
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                spacing: 1

                Text {
                    width: parent.width
                    text: MediaService.hasPlayer ? MediaService.title : "Nothing playing"
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: MediaService.hasPlayer ? MediaService.artist : "Start a player to listen"
                    font.pixelSize: 9
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "transparent"
            border.color: Theme.borderStrong
            border.width: 1
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 18

        Rectangle {
            id: previousButton
            implicitWidth: 36
            implicitHeight: 36
            radius: width / 2
            color: previousMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
            border.color: Theme.borderStrong
            border.width: 1
            scale: previousMouse.pressed ? 0.92 : (previousMouse.containsMouse ? 1.06 : 1)
            Behavior on scale { NumberAnimation { duration: Theme.animFast } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Text {
                anchors.centerIn: parent
                text: "󰒮"
                font.pixelSize: 15
                color: MediaService.canPrev ? Theme.textPrimary : Theme.textFaint
            }

            MouseArea {
                id: previousMouse
                anchors.fill: parent
                enabled: MediaService.canPrev
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: MediaService.previous()
            }
        }

        // Small lobes give the primary control the scalloped silhouette from
        // the reference without introducing a foreign colour into our theme.
        Item {
            id: playButton
            implicitWidth: 48
            implicitHeight: 48
            scale: playMouse.pressed ? 0.92 : (playMouse.containsMouse ? 1.06 : 1)
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Theme.easeOutBack
                    easing.overshoot: 1.05
                }
            }

            Repeater {
                model: 12
                delegate: Rectangle {
                    required property int index
                    width: 12
                    height: 12
                    radius: 6
                    color: MediaService.accent
                    x: playButton.width / 2 - width / 2
                       + Math.cos(index * Math.PI / 6) * 17
                    y: playButton.height / 2 - height / 2
                       + Math.sin(index * Math.PI / 6) * 17
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 40
                height: 40
                radius: 20
                color: MediaService.accent
            }

            Text {
                anchors.centerIn: parent
                text: MediaService.playing ? "󰏤" : "󰐊"
                font.pixelSize: 19
                color: "#0a0a0f"
            }

            MouseArea {
                id: playMouse
                anchors.fill: parent
                enabled: MediaService.hasPlayer
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: MediaService.playPause()
            }
        }

        Rectangle {
            id: nextButton
            implicitWidth: 36
            implicitHeight: 36
            radius: width / 2
            color: nextMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
            border.color: Theme.borderStrong
            border.width: 1
            scale: nextMouse.pressed ? 0.92 : (nextMouse.containsMouse ? 1.06 : 1)
            Behavior on scale { NumberAnimation { duration: Theme.animFast } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Text {
                anchors.centerIn: parent
                text: "󰒭"
                font.pixelSize: 15
                color: MediaService.canNext ? Theme.textPrimary : Theme.textFaint
            }

            MouseArea {
                id: nextMouse
                anchors.fill: parent
                enabled: MediaService.canNext
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: MediaService.next()
            }
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 14

        Rectangle {
            id: seekTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: seekMouse.containsMouse || seekMouse.pressed ? 5 : 3
            radius: height / 2
            color: Theme.borderStrong
            Behavior on height { NumberAnimation { duration: Theme.animFast } }

            Rectangle {
                width: (seekMouse.pressed ? seekMouse.fraction : MediaService.progress)
                       * parent.width
                height: parent.height
                radius: parent.radius
                color: MediaService.accent
                Behavior on width {
                    enabled: !seekMouse.pressed
                    NumberAnimation { duration: 400 }
                }
            }
        }

        Rectangle {
            width: 10
            height: 10
            radius: 5
            color: MediaService.accent
            anchors.verticalCenter: parent.verticalCenter
            x: (seekMouse.pressed ? seekMouse.fraction : MediaService.progress)
               * (parent.width - width)
        }

        MouseArea {
            id: seekMouse
            anchors.fill: parent
            enabled: MediaService.canSeek
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            property real fraction: 0

            function update(pointerX) {
                fraction = Math.max(0, Math.min(1, pointerX / width));
            }

            onPressed: mouse => update(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    update(mouse.x);
            }
            onReleased: MediaService.seekFraction(fraction)
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: MediaService.fmtTime(MediaService.position)
              + " / " + MediaService.fmtTime(MediaService.length)
        font.pixelSize: 9
        font.weight: Font.DemiBold
        color: Theme.textMuted
    }
}
