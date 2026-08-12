import QtQuick
import QtQuick.Layouts
import Quickshell

// One entry in the dock's pinned list: icon, name, the app_id the dock matches
// running windows against, and the reorder/remove controls.
Rectangle {
    id: entry

    property var app: ({})
    property bool isFirst: false
    property bool isLast: false

    signal moveUp
    signal moveDown
    signal removed

    Layout.fillWidth: true
    implicitHeight: 46
    radius: Theme.radiusSmall
    color: rowMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
    border.color: Theme.border
    border.width: 1
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 10

        Item {
            implicitWidth: 26
            implicitHeight: 26

            Image {
                id: icon
                anchors.fill: parent
                // Checked lookup: an unknown name yields "" and the glyph
                // below shows, instead of the icon provider's magenta
                // placeholder (which counts as Image.Ready and hides it).
                source: Quickshell.iconPath(entry.app.icon || entry.app["class"] || "", true)
                sourceSize: Qt.size(52, 52)
                smooth: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: "󰣆"
                font.pixelSize: 18
                color: Theme.textFaint
                visible: icon.status !== Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: entry.app.name || entry.app.exec || "?"
                font.pixelSize: 12
                color: Theme.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: entry.app["class"] || "no window class"
                font.pixelSize: 9
                font.family: "monospace"
                color: entry.app["class"] ? Theme.textFaint : Theme.warn
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Repeater {
            model: [
                { glyph: "󰅃", act: "up" },
                { glyph: "󰅀", act: "down" },
                { glyph: "󰅖", act: "remove" }
            ]

            delegate: Rectangle {
                required property var modelData

                readonly property bool disabled:
                    (modelData.act === "up" && entry.isFirst)
                    || (modelData.act === "down" && entry.isLast)
                readonly property bool destructive: modelData.act === "remove"

                implicitWidth: 26
                implicitHeight: 26
                radius: 6
                color: btnMouse.containsMouse && !disabled ? Theme.cardHover : "transparent"
                border.color: btnMouse.containsMouse && !disabled ? Theme.border : "transparent"
                border.width: 1
                opacity: disabled ? 0.25 : 1

                Text {
                    anchors.centerIn: parent
                    text: modelData.glyph
                    font.pixelSize: 13
                    color: btnMouse.containsMouse && parent.destructive
                           ? Theme.danger : Theme.textSecondary
                }

                MouseArea {
                    id: btnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !parent.disabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.act === "up")
                            entry.moveUp();
                        else if (modelData.act === "down")
                            entry.moveDown();
                        else
                            entry.removed();
                    }
                }
            }
        }
    }
}
