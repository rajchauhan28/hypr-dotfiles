import QtQuick
import Quickshell

// One dock slot: themed icon (emoji-free checked lookup), hover pop,
// running indicator dot.
Item {
    id: slot

    // { name, exec, iconName, running, address }
    property var entry: ({})

    signal activated
    // centre x in the slot's own coordinates has no meaning to the shell, so
    // report hover with the slot itself; the shell maps its position.
    signal hoverEntered
    signal hoverLeft

    width: Theme.iconSlot
    height: Theme.iconSlot

    Rectangle {
        anchors.centerIn: parent
        width: Theme.iconSlot - 6
        height: Theme.iconSlot - 6
        radius: Theme.radiusSmall
        color: mouse.pressed ? Theme.cardHover : (mouse.containsMouse ? Theme.cardHover : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Image {
        id: icon
        anchors.centerIn: parent
        width: Theme.iconSize
        height: Theme.iconSize
        // Checked lookup: unknown names yield "" (fallback glyph below) rather
        // than the icon provider's magenta missing-image placeholder, which
        // would count as Ready and paint a checkerboard.
        source: {
            if (!slot.entry || !slot.entry.iconName) return "";
            var direct = Quickshell.iconPath(slot.entry.iconName, true);
            if (direct !== "") return direct;
            if (typeof Config !== "undefined" && Config.getAvailableIcon) {
                return Quickshell.iconPath(Config.getAvailableIcon(slot.entry.iconName, slot.entry.name, slot.entry.class), true);
            }
            return "";
        }
        sourceSize.width: 64
        sourceSize.height: 64
        asynchronous: true
        visible: status === Image.Ready

        scale: mouse.pressed ? 0.92 : (mouse.containsMouse ? 1.18 : 1.0)
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack; easing.overshoot: 1.1 } }
    }

    Text {
        anchors.centerIn: parent
        text: "󰣆"
        font.pixelSize: 24
        color: Theme.textSecondary
        visible: icon.status !== Image.Ready
        scale: icon.scale
    }

    // Running indicator, sitting in the bottom padding of the slot.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        width: 5
        height: 5
        radius: 2.5
        color: Theme.good
        visible: opacity > 0.01
        opacity: (slot.entry && slot.entry.running) ? 1.0 : 0.0
        scale: (slot.entry && slot.entry.running) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: slot.activated()
        onContainsMouseChanged: containsMouse ? slot.hoverEntered() : slot.hoverLeft()
    }
}
