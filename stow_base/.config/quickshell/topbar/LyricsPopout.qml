import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Free-floating lyrics window: draggable, resizable, and almost entirely
// transparent.
//
// The surface itself spans the whole screen and the card is positioned inside
// it with plain x/y. That is far simpler than nudging layer-shell margins, and
// it makes "which screen edge am I nearest" a question about the card's own
// coordinates rather than a monitor query. The input mask is pinned to the
// card so the rest of the desktop stays clickable -- without it a fullscreen
// surface would swallow every click on the session.
Scope {
    id: root

    PanelWindow {
        id: win

        visible: LyricsService.popoutOpen

        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-lyrics"
        // Never take focus: this is a thing you glance at while typing
        // somewhere else.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Only the card is clickable.
        mask: Region { item: card }

        Item {
            id: card

            // Opening position: lower-left, clear of the dock, which puts it
            // against an edge so the fade has a direction to run in.
            x: 90
            y: Math.round(win.height * 0.45)
            width: 420
            height: 340

            readonly property int minWidth: 240
            readonly property int minHeight: 140

            // ---- Nearest-edge fade ------------------------------------
            readonly property real distLeft: x
            readonly property real distRight: win.width - (x + width)
            readonly property real distTop: y
            readonly property real distBottom: win.height - (y + height)

            // Within this many pixels counts as "against" an edge.
            readonly property int edgeThreshold: 64

            readonly property bool nearL: distLeft <= edgeThreshold
            readonly property bool nearR: distRight <= edgeThreshold
            readonly property bool nearT: distTop <= edgeThreshold
            readonly property bool nearB: distBottom <= edgeThreshold

            // Which edge the solid end of the gradient sits against. In a
            // corner -- near one horizontal AND one vertical edge -- the
            // vertical axis wins, so the fade runs top-to-bottom or
            // bottom-to-top rather than sideways.
            readonly property string fadeFrom: {
                var vert = nearT || nearB;
                var horiz = nearL || nearR;
                if (vert && horiz)
                    return distTop <= distBottom ? "top" : "bottom";
                if (vert)
                    return nearT ? "top" : "bottom";
                if (horiz)
                    return nearL ? "left" : "right";
                // Floating free of every edge: still fade from whichever one
                // is closest, so the look never flips to a flat wash.
                var m = Math.min(distLeft, distRight, distTop, distBottom);
                if (m === distTop)
                    return "top";
                if (m === distBottom)
                    return "bottom";
                return m === distLeft ? "left" : "right";
            }

            readonly property bool fadeVertical: fadeFrom === "top" || fadeFrom === "bottom"
            // "top" and "left" put the solid end at gradient position 0.
            readonly property bool solidFirst: fadeFrom === "top" || fadeFrom === "left"

            // Peak opacity of the backdrop. Everything else -- text, controls
            // -- stays fully opaque; only the ground fades.
            readonly property real peakAlpha: 0.10

            readonly property color solidColor: Qt.rgba(Theme.panelBg.r, Theme.panelBg.g,
                                                        Theme.panelBg.b, card.peakAlpha)
            // Same RGB at zero alpha, never "transparent": fading to the
            // default transparent black would drag a grey cast across the
            // gradient on any non-black backdrop.
            readonly property color clearColor: Qt.rgba(Theme.panelBg.r, Theme.panelBg.g,
                                                        Theme.panelBg.b, 0)

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusPanel

                gradient: Gradient {
                    orientation: card.fadeVertical ? Gradient.Vertical
                                                   : Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: card.solidFirst ? card.solidColor : card.clearColor
                    }
                    GradientStop {
                        position: 1.0
                        color: card.solidFirst ? card.clearColor : card.solidColor
                    }
                }
            }

            // ---- Drag -------------------------------------------------
            // Confined to the header strip: dragging from the body would
            // fight the lyrics list's own flicking.
            MouseArea {
                id: dragArea
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 30
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                hoverEnabled: true

                property real pressX: 0
                property real pressY: 0

                onPressed: (mouse) => {
                    pressX = mouse.x;
                    pressY = mouse.y;
                }
                onPositionChanged: (mouse) => {
                    if (!pressed)
                        return;
                    // Clamped so the card cannot be dragged off-screen and
                    // stranded where it has no grip left to grab.
                    card.x = Math.max(0, Math.min(win.width - card.width,
                                                  card.x + mouse.x - pressX));
                    card.y = Math.max(0, Math.min(win.height - card.height,
                                                  card.y + mouse.y - pressY));
                }
            }

            // ---- Header -----------------------------------------------
            RowLayout {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                height: 18
                spacing: 8

                Text {
                    text: MediaService.hasPlayer ? MediaService.title : "Lyrics"
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: LyricsService.synced
                    text: MediaService.fmtTime(LyricsService.pos)
                    font.pixelSize: 10
                    color: Theme.textMuted
                }

                Text {
                    text: "✕"
                    font.pixelSize: 11
                    color: closeMouse.containsMouse ? Theme.danger : Theme.textMuted
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.popoutOpen = false
                    }
                }
            }

            // ---- Lyrics ------------------------------------------------
            LyricsPane {
                anchors.top: header.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.bottomMargin: 12

                // Its own header and pop-out button would be redundant here,
                // and read from further away than a dashboard card, so the
                // type runs a couple of sizes larger.
                showHeader: false
                showPopoutButton: false
                baseFontSize: 13
                activeFontSize: 16
            }

            // ---- Resize grip -------------------------------------------
            MouseArea {
                id: resizeArea
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 18
                height: 18
                cursorShape: Qt.SizeFDiagCursor
                hoverEnabled: true

                property real pressX: 0
                property real pressY: 0

                onPressed: (mouse) => {
                    pressX = mouse.x;
                    pressY = mouse.y;
                }
                onPositionChanged: (mouse) => {
                    if (!pressed)
                        return;
                    card.width = Math.max(card.minWidth,
                                          Math.min(win.width - card.x,
                                                   card.width + mouse.x - pressX));
                    card.height = Math.max(card.minHeight,
                                           Math.min(win.height - card.y,
                                                    card.height + mouse.y - pressY));
                }

                // Two short strokes, the usual resize-corner hint. Only drawn
                // on hover so it does not clutter a window meant to be nearly
                // invisible.
                Canvas {
                    anchors.fill: parent
                    opacity: resizeArea.containsMouse ? 1 : 0.35
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = Theme.textMuted;
                        ctx.lineWidth = 1.5;
                        for (var i = 0; i < 2; i++) {
                            var o = 5 + i * 5;
                            ctx.beginPath();
                            ctx.moveTo(width - o, height - 3);
                            ctx.lineTo(width - 3, height - o);
                            ctx.stroke();
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "lyrics"

        // open/close rather than show/hide: `qs ipc` owns the name `show`.
        function open(): void { LyricsService.popoutOpen = true; }
        function close(): void { LyricsService.popoutOpen = false; }
        function toggle(): void { LyricsService.togglePopout(); }
    }
}
