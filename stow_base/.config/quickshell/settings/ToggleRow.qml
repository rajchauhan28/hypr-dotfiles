import QtQuick
import QtQuick.Layouts

// One on/off knob, bound straight to Config like SliderRow. The switch is the
// same pill AiPage draws inline; the whole row is the click target, not just
// the 40 px pill.
Item {
    id: row

    property string section: ""
    property string key: ""
    property string label: ""

    readonly property bool checked: Config.get(row.section, row.key) === true
    readonly property bool modified: !Config.isDefault(row.section, row.key)

    Layout.fillWidth: true
    implicitHeight: 30

    RowLayout {
        anchors.fill: parent
        spacing: 6

        Text {
            text: row.label
            font.pixelSize: 11
            color: Theme.textSecondary
        }

        Rectangle {
            // Quiet marker that this knob is no longer at its default.
            visible: row.modified
            width: 5
            height: 5
            radius: 2.5
            color: Theme.accent
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            id: pill
            implicitWidth: 40
            implicitHeight: 22
            radius: height / 2
            color: row.checked ? Theme.accent : Theme.cardAlt
            border.color: row.checked ? Theme.accent : Theme.borderStrong
            Behavior on color { ColorAnimation { duration: 140 } }

            Rectangle {
                width: 16
                height: 16
                radius: 8
                y: 3
                x: row.checked ? pill.width - width - 3 : 3
                color: row.checked ? Theme.onAccent : Theme.textSecondary
                Behavior on x { NumberAnimation { duration: 140 } }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Config.set(row.section, row.key, !row.checked)
    }
}
