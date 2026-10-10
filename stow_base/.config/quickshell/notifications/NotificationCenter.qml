import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../common" as Common

// swaync-style notification center: a sheet on the right edge listing the
// SQLite-backed history (NotifStore), newest first. Super+N toggles it; Esc or
// a click outside the sheet closes it. Popups are hidden while it is open.
Scope {
    id: center

    readonly property bool open: NotifStore.centerOpen
    property real now: Date.now()

    Timer {
        interval: 30000
        repeat: true
        running: center.open
        triggeredOnStart: true
        onTriggered: center.now = Date.now()
    }

    function ago(ts) {
        var s = Math.max(0, Math.floor((center.now - ts) / 1000));
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m ago";
        if (s < 86400) return Math.floor(s / 3600) + "h ago";
        var d = new Date(ts);
        var yesterday = new Date(center.now);
        yesterday.setHours(0, 0, 0, 0);
        yesterday.setDate(yesterday.getDate() - 1);
        if (d >= yesterday)
            return "Yesterday " + Qt.formatTime(d, "HH:mm");
        return Qt.formatDateTime(d, "d MMM HH:mm");
    }

    function iconSource(icon) {
        if (!icon) return "";
        if (icon.indexOf("/") === 0) return "file://" + icon;
        if (icon.indexOf("file://") === 0 || icon.indexOf("image://") === 0) return icon;
        return Quickshell.iconPath(icon, true);
    }

    PanelWindow {
        id: win

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: center.open || sheet.slide < 0.999

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: center.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-notification-center"

        MouseArea {
            anchors.fill: parent
            onClicked: NotifStore.centerOpen = false
        }

        Rectangle {
            id: sheet

            // 0 = on screen, 1 = parked off the right edge.
            property real slide: center.open ? 0 : 1
            Behavior on slide { NumberAnimation { duration: Theme.animPanel; easing.type: Theme.easeOutExpo } }

            width: Theme.centerWidth
            height: win.height - 2 * Theme.centerMargin
            x: win.width - width - Theme.centerMargin + slide * (width + Theme.centerMargin + 24)
            y: Theme.centerMargin
            radius: Theme.radiusPanel
            color: Theme.panelBg
            border.width: Theme.glass ? 0 : 1
            border.color: Theme.panelBorder

            // Clicks on the sheet itself must not reach the close catcher.
            MouseArea { anchors.fill: parent }

            Common.GlassRim {
                anchors.fill: parent
                radius: parent.radius
                visible: Theme.glass
            }

            Item {
                id: keys
                focus: true
                Keys.onEscapePressed: NotifStore.centerOpen = false
            }

            Connections {
                target: NotifStore
                function onCenterOpenChanged() {
                    if (NotifStore.centerOpen) {
                        list.positionViewAtBeginning();
                        keys.forceActiveFocus();
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // --- Header -----------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Notifications"
                        color: Theme.textPrimary
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        visible: NotifStore.history.length > 0
                        implicitWidth: countText.implicitWidth + 14
                        implicitHeight: 20
                        radius: 10
                        color: Theme.card
                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: NotifStore.history.length
                            color: Theme.textSecondary
                            font.pixelSize: 11
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        visible: NotifStore.history.length > 0
                        implicitWidth: clearText.implicitWidth + 20
                        implicitHeight: 28
                        radius: Theme.radiusSmall
                        color: clearMouse.containsMouse ? Theme.cardHover : Theme.card
                        border.width: 1
                        border.color: Theme.border
                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: "Clear all"
                            color: Theme.textPrimary
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotifStore.clear()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.divider
                }

                // --- History ----------------------------------------------
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: NotifStore.history
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: row

                        required property var modelData

                        width: ListView.view.width
                        height: body.implicitHeight + 20
                        radius: Theme.radiusSmall
                        color: hover.hovered ? Theme.cardHover : Theme.card
                        border.width: row.modelData.urgency === 2 ? 1 : 0
                        border.color: Theme.danger

                        HoverHandler { id: hover }

                        RowLayout {
                            id: body
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignTop

                                Image {
                                    id: icon
                                    anchors.fill: parent
                                    source: center.iconSource(row.modelData.icon)
                                    sourceSize: Qt.size(64, 64)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: false  // icon-provider sources load via QIcon/QPixmap, which abort qs off the GUI thread
                                    smooth: true
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: icon.status !== Image.Ready
                                    text: "󰂚"
                                    color: Theme.textMuted
                                    font.pixelSize: 18
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.app || "Notification"
                                        color: Theme.textSecondary
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }

                                    // Time, swapped for a delete button on hover.
                                    Item {
                                        implicitWidth: Math.max(timeText.implicitWidth, 20)
                                        implicitHeight: 20

                                        Text {
                                            id: timeText
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !hover.hovered
                                            text: center.ago(row.modelData.ts)
                                            color: Theme.textMuted
                                            font.pixelSize: 11
                                        }

                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: hover.hovered
                                            width: 20
                                            height: 20
                                            radius: 6
                                            color: delMouse.containsMouse ? Theme.panelBorder : "transparent"
                                            Text {
                                                anchors.centerIn: parent
                                                text: "×"
                                                color: Theme.textSecondary
                                                font.pixelSize: 15
                                            }
                                            MouseArea {
                                                id: delMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: NotifStore.remove(row.modelData.id)
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: !!row.modelData.summary
                                    text: row.modelData.summary
                                    color: Theme.textPrimary
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: !!row.modelData.body
                                    text: row.modelData.body
                                    textFormat: Text.StyledText
                                    color: Theme.textSecondary
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: NotifStore.history.length === 0
                        spacing: 6
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰂛"
                            color: Theme.textMuted
                            font.pixelSize: 34
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No notifications"
                            color: Theme.textMuted
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
