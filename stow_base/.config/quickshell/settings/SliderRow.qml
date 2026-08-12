import QtQuick
import QtQuick.Layouts

// One numeric knob, bound straight to Config. Dragging writes on every step so
// the live panel follows the pointer; Config debounces the actual file write,
// so a whole drag costs one save.
Item {
    id: row

    property string section: ""
    property string key: ""
    property string label: ""
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string suffix: ""

    readonly property real value: Config.get(row.section, row.key)
    readonly property bool modified: !Config.isDefault(row.section, row.key)

    Layout.fillWidth: true
    implicitHeight: 40

    function commit(fraction) {
        var f = Math.max(0, Math.min(1, fraction));
        var raw = row.from + f * (row.to - row.from);
        var snapped = row.from + Math.round((raw - row.from) / row.step) * row.step;
        // Float steps (0.01) leave a tail of binary noise that would show up in
        // the JSON as 0.30000000000000004.
        snapped = parseFloat(snapped.toFixed(4));
        if (snapped !== row.value)
            Config.set(row.section, row.key, snapped);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
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

            Text {
                text: row.value.toFixed(row.decimals) + row.suffix
                font.pixelSize: 11
                font.family: "monospace"
                color: track.active ? Theme.accent : Theme.textMuted
            }
        }

        Item {
            id: track
            Layout.fillWidth: true
            implicitHeight: 16

            readonly property bool active: trackMouse.pressed || trackMouse.containsMouse
            readonly property real fraction:
                row.to > row.from ? (row.value - row.from) / (row.to - row.from) : 0

            Rectangle {
                id: rail
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: track.active ? 6 : 4
                radius: height / 2
                color: Theme.cardAlt
                Behavior on height { NumberAnimation { duration: 120 } }

                Rectangle {
                    width: track.fraction * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }
            }

            Rectangle {
                width: 11
                height: 11
                radius: 5.5
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                x: track.fraction * (parent.width - width)
                opacity: track.active ? 1 : 0.65
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            MouseArea {
                id: trackMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => row.commit(mouse.x / width)
                onPositionChanged: mouse => { if (pressed) row.commit(mouse.x / width); }
                onWheel: wheel => {
                    var dir = wheel.angleDelta.y > 0 ? 1 : -1;
                    var next = row.value + dir * row.step;
                    row.commit((next - row.from) / (row.to - row.from));
                }
            }
        }
    }
}
