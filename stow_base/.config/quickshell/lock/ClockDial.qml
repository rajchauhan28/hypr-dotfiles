import QtQuick

Item {
    id: dial

    property real dialRadius: 260
    property real value: 0
    property color tickColor: "#90f8fafc"
    property color labelColor: "#b8f8fafc"
    property int labelEvery: 5
    property int labelSize: 13
    property real tickLength: 11
    property real majorTickLength: 20
    property real tickWidth: 2
    property real majorTickWidth: 4

    width: dialRadius * 2
    height: dialRadius * 2
    rotation: value * 6

    Repeater {
        model: 60

        delegate: Item {
            id: tick

            required property int index
            readonly property int labelValue: (15 - index + 60) % 60

            x: dial.width / 2
            y: dial.height / 2
            width: 1
            height: 1
            rotation: index * 6
            transformOrigin: Item.Center

            Rectangle {
                width: tick.index % dial.labelEvery === 0
                       ? dial.majorTickWidth : dial.tickWidth
                height: tick.index % dial.labelEvery === 0
                        ? dial.majorTickLength : dial.tickLength
                radius: width / 2
                x: -width / 2
                y: -dial.dialRadius
                color: dial.tickColor
                opacity: tick.index % dial.labelEvery === 0 ? 0.55 : 0.18
            }

            Text {
                text: String(tick.labelValue).padStart(2, "0")
                visible: tick.labelValue % dial.labelEvery === 0
                x: -width / 2
                y: -dial.dialRadius - dial.majorTickLength - 22
                rotation: -tick.rotation - dial.rotation
                color: dial.labelColor
                opacity: 0.72
                font.family: "Audiowide"
                font.pixelSize: dial.labelSize
                font.weight: Font.Black
                font.letterSpacing: 1.2
            }
        }
    }
}
