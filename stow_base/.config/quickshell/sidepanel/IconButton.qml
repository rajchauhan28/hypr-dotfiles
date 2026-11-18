import QtQuick

// One slot in the icon strip: an optional click action plus optional scroll.
Item {
    id: btn

    property string glyph: ""
    property string altGlyph: ""     // shown when `alt` is true (muted / off)
    property bool alt: false
    property bool available: true
    property bool clickable: false
    property bool scrollable: false
    property color activeColor: Theme.textPrimary

    signal activated
    signal scrolled(int delta)       // +1 up, -1 down

    implicitWidth: Theme.iconSlot
    implicitHeight: Theme.iconSlot

    Rectangle {
        anchors.centerIn: parent
        width: Theme.iconSlot - 6
        height: Theme.iconSlot - 6
        radius: Theme.radiusSmall
        color: mouse.pressed && btn.clickable ? Theme.cardHover : (mouse.containsMouse ? Theme.cardHover : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Text {
        anchors.centerIn: parent
        text: btn.alt && btn.altGlyph !== "" ? btn.altGlyph : btn.glyph
        font.pixelSize: 19
        color: !btn.available ? Theme.textFaint
                              : (btn.alt ? Theme.danger : btn.activeColor)
        scale: mouse.pressed && btn.clickable ? 0.92 : (mouse.containsMouse ? 1.12 : 1.0)
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack; easing.overshoot: 1.1 } }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        // A scroll-only control still wants the hover highlight, but not a
        // pointing-hand cursor promising a click that does nothing.
        cursorShape: btn.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: btn.clickable ? Qt.LeftButton : Qt.NoButton
        onClicked: if (btn.available) btn.activated()
        // Trackpads send many small deltas, and a sideways swipe arrives with
        // y == 0, which `y > 0 ? 1 : -1` counted as a full step DOWN. Step
        // once per 120 units of vertical travel, like one mouse-wheel notch
        // (the same accumulator WallpaperCarousel uses).
        property real wheelAcc: 0
        onWheel: wheel => {
            if (!(btn.scrollable && btn.available))
                return;
            wheelAcc += wheel.angleDelta.y;
            while (Math.abs(wheelAcc) >= 120) {
                btn.scrolled(wheelAcc > 0 ? 1 : -1);
                wheelAcc -= wheelAcc > 0 ? 120 : -120;
            }
        }
    }
}
