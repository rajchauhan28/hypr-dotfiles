import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common" as Common

// A compact popover showing the most-recent cliphist entries. The full search
// surface is still the launcher; this is the "paste the thing from a minute
// ago without typing" surface, driven by its own keybind.
//
// Open with: qs ipc call clipboard toggle
Scope {
    id: root

    property bool shown: false
    property var entries: []        // [{ id, preview }]

    function refresh() {
        listProc.running = true;
    }

    function open() {
        root.refresh();
        root.shown = true;
    }

    function close() {
        root.shown = false;
    }

    function toggle() {
        if (root.shown) close(); else open();
    }

    // cliphist orders newest-first already; the preview column is truncated
    // by cliphist itself to ~100 chars, which is what we want in a row.
    Process {
        id: listProc
        command: ["sh", "-c", "cliphist list | head -n " + Theme.rowCount]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (text || "").split("\n");
                var out = [];
                for (var i = 0; i < lines.length; i++) {
                    var ln = lines[i];
                    if (!ln) continue;
                    // Each row is "<id>\t<preview>" per cliphist's output.
                    var tab = ln.indexOf("\t");
                    if (tab < 0) continue;
                    out.push({ id: ln.substring(0, tab), preview: ln.substring(tab + 1) });
                }
                root.entries = out;
            }
        }
    }

    function paste(id) {
        // Decode into wl-copy; same path the launcher takes.
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", id]);
        root.close();
    }

    function remove(id) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | cliphist delete", "sh", id]);
        // Give cliphist a beat to actually remove the row before re-listing.
        removeDebounce.restart();
    }

    Timer {
        id: removeDebounce
        interval: 80
        repeat: false
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "clipboard"
        function open(): void   { root.open(); }
        function close(): void  { root.close(); }
        function toggle(): void { root.toggle(); }
    }

    PanelWindow {
        id: win

        anchors { bottom: true; right: true }
        exclusiveZone: 0
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-clipboard"

        implicitWidth: Theme.panelWidth + 20
        implicitHeight: Theme.panelHeight + 80

        visible: root.shown

        Rectangle {
            id: card
            x: 10
            // Bottom-right corner lifted 60px off the edge to clear the dock.
            y: parent.height - height - 60
            width: Theme.panelWidth
            height: Math.min(Theme.panelHeight, 44 + root.entries.length * Theme.rowHeight)
            radius: Theme.radiusPanel
            color: Theme.panelBg
            border.width: 1
            border.color: Theme.panelBorder

            Behavior on height { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutQuint } }

            Common.GlassRim {
                anchors.fill: parent
                radius: parent.radius
                visible: Theme.glass
            }

            // ESC closes.
            Keys.onEscapePressed: root.close()
            focus: root.shown

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Row {
                    width: parent.width
                    height: 24
                    Text {
                        text: "Clipboard"
                        color: Theme.textPrimary
                        font.pixelSize: 14
                        font.bold: true
                    }
                    Item { height: 1; width: parent.width - 160 }
                    Text {
                        text: root.entries.length + " item" + (root.entries.length === 1 ? "" : "s")
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.divider }

                ListView {
                    width: parent.width
                    height: parent.height - 32
                    clip: true
                    model: root.entries
                    spacing: 2

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: Theme.rowHeight
                        radius: 8
                        color: mouse.containsMouse ? Theme.cardHover : Theme.card

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.preview
                                color: Theme.textPrimary
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                width: parent.width - 36
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                height: 22
                                radius: 6
                                color: delMouse.containsMouse ? Theme.cardHover : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: Theme.textSecondary
                                    font.pixelSize: 16
                                }
                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.remove(modelData.id)
                                }
                            }
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            anchors.rightMargin: 32   // leave the × button alone
                            hoverEnabled: true
                            onClicked: root.paste(modelData.id)
                        }
                    }

                    // Empty state.
                    Text {
                        anchors.centerIn: parent
                        visible: root.entries.length === 0
                        text: "cliphist is empty"
                        color: Theme.textSecondary
                        font.pixelSize: 12
                    }
                }
            }
        }

        // Click outside the card closes it. The MouseArea sits beneath card so
        // card's own hits take priority.
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: root.close()
        }
    }
}
