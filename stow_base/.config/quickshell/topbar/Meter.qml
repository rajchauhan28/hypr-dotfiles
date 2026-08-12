import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: meter

    property string label: ""
    property real value: 0          // 0..100
    property string valueText: ""
    property color barColor: Theme.meterColor(meter.value)

    spacing: 5

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: meter.label
            font.pixelSize: 11
            color: Theme.textSecondary
        }
        Item { Layout.fillWidth: true }
        Text {
            text: meter.valueText !== "" ? meter.valueText : Math.round(meter.value) + "%"
            font.pixelSize: 11
            font.bold: true
            color: Theme.textPrimary
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 6
        radius: 3
        color: Theme.cardAlt
        border.color: Theme.border
        border.width: 1

        Rectangle {
            width: Math.max(0, Math.min(1, meter.value / 100.0)) * (parent.width - 2)
            height: parent.height - 2
            x: 1
            y: 1
            radius: 3
            color: meter.barColor
            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutQuint } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }
}
