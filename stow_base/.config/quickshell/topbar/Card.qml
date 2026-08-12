import QtQuick

Rectangle {
    id: card

    property string heading: ""

    radius: Theme.radiusCard
    color: Theme.card
    border.color: Theme.border
    border.width: 1

    Text {
        visible: card.heading !== ""
        text: card.heading
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 14
        anchors.topMargin: 12
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.2
        color: Theme.textMuted
    }
}
