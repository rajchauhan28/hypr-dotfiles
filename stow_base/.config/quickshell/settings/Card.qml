import QtQuick
import QtQuick.Layouts

// A titled section. The reset link only appears once something in the section
// differs from its default, so an untouched page carries no extra chrome.
Rectangle {
    id: card

    property string title: ""
    property string subtitle: ""
    property string section: ""
    // Which keys this card owns. Several cards can share a section (the dock's
    // size, reveal and preview knobs all live under "dock"), so reset has to be
    // scoped to the card or one card's link would silently revert the others.
    property var keys: []
    default property alias content: body.data

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Theme.cardPadding * 2
    radius: Theme.radiusCard
    color: Theme.card
    border.color: Theme.border
    border.width: 1

    readonly property var ownedKeys:
        card.keys.length > 0 ? card.keys
                             : (card.section !== "" ? Object.keys(Config.defaults[card.section]) : [])

    readonly property bool dirty: {
        for (var i = 0; i < card.ownedKeys.length; i++)
            if (!Config.isDefault(card.section, card.ownedKeys[i]))
                return true;
        return false;
    }

    function reset() {
        for (var i = 0; i < card.ownedKeys.length; i++) {
            var k = card.ownedKeys[i];
            Config.set(card.section, k, Config.defaults[card.section][k]);
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.cardPadding
        spacing: 10

        // Anchored rather than a RowLayout: the reset link has to sit hard
        // against the right edge whether or not the card has a subtitle, and a
        // fillWidth column sizes itself to its text instead.
        Item {
            Layout.fillWidth: true
            implicitHeight: header.implicitHeight

            ColumnLayout {
                id: header
                anchors.left: parent.left
                anchors.right: resetLink.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: card.title
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: card.subtitle !== ""
                    text: card.subtitle
                    font.pixelSize: 10
                    color: Theme.textFaint
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Text {
                id: resetLink
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: card.dirty
                text: "reset"
                font.pixelSize: 10
                color: resetMouse.containsMouse ? Theme.warn : Theme.textFaint

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.reset()
                }
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 4
        }
    }
}
