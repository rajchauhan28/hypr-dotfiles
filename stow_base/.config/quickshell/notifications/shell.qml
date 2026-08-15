//@ pragma UseQApplication

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    NotificationServer {
        id: server

        // Popups are ephemeral; a shell reload should not resurrect them.
        keepOnReload: false

        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        imageSupported: true
        persistenceSupported: false
        inlineReplySupported: false

        // Tracking is what keeps the object alive past the D-Bus call. The
        // entry stays tracked while it collapses and only calls dismiss()
        // once its exit animation has landed, so nothing pops out abruptly.
        onNotification: (notif) => {
            notif.tracked = true;
        }
    }

    PanelWindow {
        id: win

        // Full height even though the card only occupies the top: resizing a
        // layer surface every time the stack grows makes the slide stutter.
        // The input mask, not the surface, decides what is clickable.
        anchors { top: true; bottom: true; right: true }

        exclusiveZone: 0
        implicitWidth: Theme.panelWidth
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-notifications"

        readonly property int count: server.trackedNotifications.values.length
        readonly property bool shown: count > 0

        // --- Geometry shared by silhouette, mask and content ---------------
        readonly property real edgeX: width
        readonly property real bodyTop: Theme.topMargin
        // The card is exactly as tall as its rows; the Behavior is what makes
        // it grow and shrink around them instead of snapping.
        property real bodyHeight: shown ? stack.implicitHeight : 0
        Behavior on bodyHeight {
            NumberAnimation { duration: Theme.animPanel; easing.type: Theme.easeOutExpo }
        }

        readonly property real bodyBottom: bodyTop + bodyHeight
        readonly property real bodyLeft: edgeX - Theme.panelWidth

        // Both radii collapse with the card so the path stays well-formed at
        // height 0 instead of self-intersecting on the way out.
        readonly property real filletR: Math.min(Theme.cornerFillet, bodyHeight / 2)
        readonly property real cornerR: Math.min(Theme.radiusPanel, bodyHeight / 2)

        // The whole card travels in from off-screen. Everything beyond edgeX
        // is outside the layer surface, so the motion reads as entering from
        // the right edge rather than fading up in place.
        property real slideX: shown ? 0 : Theme.panelWidth + Theme.cornerFillet
        Behavior on slideX {
            NumberAnimation { duration: Theme.animSlide; easing.type: Theme.easeOutExpo }
        }

        // Only the card takes input. Everything else on this full-height
        // surface must stay click-through or the popup would eat the desktop.
        mask: Region {
            item: win.shown ? cardMask : null
        }

        Item {
            id: cardMask
            x: win.bodyLeft + win.slideX
            y: win.bodyTop
            width: Theme.panelWidth
            height: win.bodyHeight
        }

        // --- Card silhouette ----------------------------------------------
        // One closed path for the whole stack, which is what makes several
        // notifications read as a single card welded to the screen edge. A
        // Rectangle cannot produce the concave scoops where the card meets
        // the edge above and below.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true
            visible: win.bodyHeight > 0.5
            transform: Translate { x: win.slideX }

            ShapePath {
                fillColor: Theme.panelBg
                strokeColor: Theme.panelBorder
                strokeWidth: 1

                // Start on the edge, below the card, and run counter-clockwise.
                startX: win.edgeX
                startY: win.bodyBottom + win.filletR

                // Bottom scoop. The control point sits at the inner corner
                // where the two tangents meet, so the curve leaves the edge
                // vertically and arrives at the card horizontally -- concave.
                // Putting it at the outer corner reverses both and bulges out.
                PathQuad {
                    x: win.edgeX - win.filletR
                    y: win.bodyBottom
                    controlX: win.edgeX
                    controlY: win.bodyBottom
                }

                PathLine { x: win.bodyLeft + win.cornerR; y: win.bodyBottom }
                PathQuad {
                    x: win.bodyLeft
                    y: win.bodyBottom - win.cornerR
                    controlX: win.bodyLeft
                    controlY: win.bodyBottom
                }

                PathLine { x: win.bodyLeft; y: win.bodyTop + win.cornerR }
                PathQuad {
                    x: win.bodyLeft + win.cornerR
                    y: win.bodyTop
                    controlX: win.bodyLeft
                    controlY: win.bodyTop
                }

                // Mirrored scoop at the top.
                PathLine { x: win.edgeX - win.filletR; y: win.bodyTop }
                PathQuad {
                    x: win.edgeX
                    y: win.bodyTop - win.filletR
                    controlX: win.edgeX
                    controlY: win.bodyTop
                }

                // Close back down the screen edge.
                PathLine { x: win.edgeX; y: win.bodyBottom + win.filletR }
            }
        }

        // --- Rows ----------------------------------------------------------
        Item {
            x: win.bodyLeft
            y: win.bodyTop
            width: Theme.panelWidth
            height: win.bodyHeight
            clip: true
            transform: Translate { x: win.slideX }

            Column {
                id: stack
                width: parent.width

                Repeater {
                    model: server.trackedNotifications

                    delegate: NotificationEntry {
                        required property var modelData
                        required property int index

                        notif: modelData
                        entryIndex: index
                        width: stack.width

                        onRequestDismiss: notif.dismiss()
                    }
                }
            }
        }

        // Beyond maxVisible the oldest rows are retired so the card cannot
        // grow past the screen. Retiring the oldest keeps the newest visible.
        onCountChanged: {
            var items = server.trackedNotifications.values;
            var excess = items.length - Theme.maxVisible;
            for (var i = 0; i < excess; i++)
                items[i].dismiss();
        }
    }

    // Super+N used to open swaync's panel. There is no history panel yet, so
    // the bind now clears whatever is on screen.
    IpcHandler {
        target: "notifications"

        function dismissAll(): void {
            var items = server.trackedNotifications.values.slice();
            for (var i = 0; i < items.length; i++)
                items[i].dismiss();
        }

        function count(): int {
            return server.trackedNotifications.values.length;
        }
    }
}
